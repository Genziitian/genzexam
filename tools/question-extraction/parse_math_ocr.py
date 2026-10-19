from pathlib import Path
from html.parser import HTMLParser
import re,json,unicodedata,sys
from fractions import Fraction
sys.path.insert(0,str(Path(__file__).parent))
from extract_batch import ROOT,block,source_metadata

class TableText(HTMLParser):
 def __init__(self):super().__init__(convert_charrefs=True);self.rows=[];self.row=[];self.cell=None
 def handle_starttag(self,tag,attrs):
  if tag=='tr':self.row=[]
  if tag in ['td','th']:self.cell=''
  if tag=='br' and self.cell is not None:self.cell+='; '
  if tag=='img' and self.cell is not None:self.cell+='[Original source diagram]'
 def handle_data(self,data):
  if self.cell is not None:self.cell+=data
 def handle_endtag(self,tag):
  if tag in ['td','th'] and self.cell is not None:self.row.append(self.cell.strip());self.cell=None
  if tag=='tr' and self.row:self.rows.append(self.row)

def clean(raw):
 text=re.sub(r'<\|det\|>.*?<\|/det\|>','',raw)
 text=re.sub(r'<PAGE>|<｜end▁of▁sentence｜>|<｜begin▁of▁sentence｜>','',text)
 def flatten(m):
  parser=TableText();parser.feed(m[0]);return '\n'.join(' | '.join(c for c in row if c) for row in parser.rows)
 text=re.sub(r'<table\b[^>]*>[\s\S]*?</table>',flatten,text,flags=re.I)
 text=re.sub(r'<img\b[^>]*>','[Original source diagram]',text,flags=re.I)
 lines=[]
 for ln in text.splitlines():
  if re.search(r'Gen-Z.*(?:Video Solutions|IITian)|Ecosystem.*genziitian|genziitian.in/courses.*YouTube',ln,re.I):continue
  lines.append(ln.rstrip())
 return '\n'.join(lines).strip()

def canonical(s):
 s=unicodedata.normalize('NFKC',s)
 s=s.replace('−','-').replace('–','-').replace('→',r'\to')
 s=re.sub(r'\\(?:rightarrow|longrightarrow|Rightarrow|Longrightarrow)',r'\\to',s)
 s=re.sub(r'\\(?:left|right|quad|qquad|displaystyle|,|;|!)','',s)
 s=re.sub(r'\\(?:begin|end)\{[a-zA-Z*]+\}','',s)
 s=re.sub(r'\\(?:text|mathrm|mathbf|mathit|mathbb)\{([^{}]*)\}',r'\1',s)
 s=re.sub(r'\\[()[\]]|\$','',s)
 s=re.sub(r'^\s*[•*\-]\s+','',s)
 return re.sub(r'[\s{}.,:;]+','',s).lower().rstrip('.')

def number_answer(s):
 s=re.sub(r'\\[()[\]]|\$','',s).replace('−','-').strip()
 s=re.sub(r'^\s*(?:[a-zA-Z]|\\[a-z]+)(?:_\{?\w+\}?)?\s*=\s*','',s)
 tol=.01
 match=re.search(r'\(?\s*[±]\s*([\d.]+)\s*\)?',s)
 if match:tol=float(match[1]);s=s[:match.start()].strip()
 s=re.sub(r'\s+','',s).rstrip('.')
 if re.fullmatch(r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?',s):return float(s),tol
 frac=re.fullmatch(r'([+-]?)\\(?:d?frac)\{([+-]?\d+)\}\{([+-]?\d+)\}',s)
 if frac:return (-1 if frac[1]=='-' else 1)*float(Fraction(int(frac[2]),int(frac[3]))),tol
 frac=re.fullmatch(r'([+-]?\d+)/([+-]?\d+)',s)
 if frac:return float(Fraction(int(frac[1]),int(frac[2]))),tol
 return None

def textblocks(text):
 blocks=[]
 for part in re.split(r'(```[\s\S]*?```)',text):
  if not part.strip():continue
  if part.startswith('```'):
   lang,_,value=part[3:-3].partition('\n');blocks.append(block(value,'code',lang.strip() if lang.strip() in ['python','pseudocode'] else 'text'))
  else:blocks.append(block(part))
 return blocks

def parse_text(text,context='',solution=''):
 issues=[];text=clean(text);context=clean(context);solution=clean(solution)
 text=re.sub(r'^\s*\d+\.\s*Question\s*','',text,flags=re.I)
 match=re.search(r'^\s*(?:\d+\.1\.?\s*)?Answers?\s*:\s*',text,re.I|re.M)
 if not match:return None,['Missing answer heading in OCR']
 prompt=text[:match.start()].strip();answer=text[match.end():].strip()
 answer=re.split(r'^\s*\d+\.2\.?\s*Solution',answer,flags=re.I|re.M)[0].strip()
 options=[];prefix=[];current=None
 for line in prompt.splitlines():
  option=re.match(r'^\s*(?:[□☐⃝○◯]|\[\s*\]|-\s*\[\s*\]|\\\(\s*\\(?:square|Box)\s*\\\))\s*(.*)',line)
  if option:
   if current is not None:options.append('\n'.join(current).strip())
   current=[option[1]]
  elif current is None:prefix.append(line)
  else:current.append(line)
 if current is not None:options.append('\n'.join(current).strip())
 stem='\n'.join(prefix).strip()
 if not stem:issues.append('Missing question stem')
 if '[Original source diagram]' in text or '[Original source diagram]' in context:issues.append('Original diagram needs faithful attachment or transcription')
 if '<' in text and re.search(r'</?[a-zA-Z]',text):issues.append('Unconverted markup needs review')
 q={'type':'','prompt':textblocks(context)+textblocks(stem),'marks':1,'difficulty':'medium'}
 if options:
  q['options']=[textblocks(o) for o in options]
  if len(options)<2:issues.append('Only one option was recovered')
  parts=[];buf=[]
  for line in answer.splitlines():
   m=re.match(r'^\s*[•*\-]\s+(.+)',line)
   if m:
    if buf:parts.append('\n'.join(buf).strip())
    buf=[m[1]]
   else:buf.append(line)
  if buf:parts.append('\n'.join(buf).strip())
  parts=[p for p in parts if p]
  keys=[]
  for part in parts:
   norm=canonical(part);matches=[i for i,o in enumerate(options) if canonical(o)==norm]
   if len(matches)==1:keys+=matches;continue
   option_ids=re.findall(r'\boption\s*(\d+)\b',part,re.I)
   if option_ids and all(1<=int(i)<=len(options) for i in option_ids):keys += [int(i)-1 for i in option_ids];continue
   if re.fullmatch(r'[A-H](?:\s*[,;]\s*[A-H])*',part.strip(),re.I):
    keys += [ord(s.upper())-65 for s in re.findall('[A-H]',part,re.I)];continue
   issues.append('Answer text does not uniquely match a recovered option: '+part[:150])
  keys=sorted(set(keys))
  multi=len(keys)>1 or bool(re.search(r'select all|which.*are (?:true|correct)|set of correct|all (?:true|correct)',stem,re.I))
  q['type']='mcq_multi' if multi else 'mcq_single'
  if not keys or any(k<0 or k>=len(options) for k in keys):issues.append('No valid option key')
  if multi:q['correct_answers']=keys
  elif keys:q['correct_answer']=keys[0]
 else:
  value=number_answer(answer)
  if value:q.update(type='numerical',numerical_answer=value[0],numerical_tolerance=value[1])
  else:
   plain=re.sub(r'\\[()[\]]|\$','',answer).strip()
   q.update(type='short_answer',acceptable_answers=[plain] if plain else [])
   if not plain:issues.append('Missing answer content')
   if re.search(r'select|options|which.*correct',stem,re.I):issues.append('No option markers recovered for a selection question')
 if solution:
  solution=re.sub(r'^\s*\d+\.2\.?\s*Solution\s*','',solution,flags=re.I)
  q['explanation']=textblocks(solution)
 else:issues.append('Worked solution still needs clean transcription')
 if re.search(r'\b(?:above|previous|preceding)\b',stem,re.I) and not context:issues.append('Referenced earlier context needs attachment')
 return q,issues

def read_regions(regions,folder):
 chunks=[]
 for region in regions:
  p=folder/(Path(region['path']).stem+'.md');meta=p.with_suffix('.json')
  if not p.exists() or not meta.exists() or not json.loads(meta.read_text()).get('complete'):return None
  chunks.append(p.read_text())
 return '\n'.join(chunks)

def main():
 rows=json.loads((ROOT/'maths-regions.json').read_text());out=[]
 for row in rows:
  if 'Assignment 1 (' in row['source']:continue
  text=read_regions(row['regions'],ROOT/'maths-ocr')
  if text is None:continue
  context=read_regions(row.get('context_regions',[]),ROOT/'maths-ocr')
  solution=read_regions(row.get('solution_regions',[]),ROOT/'maths-solution-ocr')
  q,issues=parse_text(text,context or '',solution or '')
  if context is None:issues.append('Shared passage OCR is not complete')
  subject,section,title=source_metadata(row['source'])
  out.append({**row,'subject':subject,'section':section,'quiz_title':title,'question':q,'issues':issues,'ocr_text':clean(text)})
 (ROOT/'maths-candidates.json').write_text(json.dumps(out,indent=2,ensure_ascii=False)+'\n')
 print('Maths 2 OCR questions structured:',len(out),'without review flags:',sum(not x['issues'] for x in out))

if __name__=='__main__':
 assert number_answer(r'\(m=-3\)')==(-3,.01)
 assert number_answer(r'\frac{3}{4}')==(.75,.01)
 assert canonical(r'i) \(\rightarrow\) b) \(\rightarrow\) 3)')==canonical('i) → b) → 3)')
 main()
