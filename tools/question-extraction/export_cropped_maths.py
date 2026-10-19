from pathlib import Path
import json,re,sys,math
from PIL import Image
from find_checkbox import checkbox_boxes
import pdfplumber
sys.path.insert(0,str(Path(__file__).parent))
from extract_batch import ROOT,PROJECT,balanced_sizes,source_metadata
from parse_math_ocr import canonical,number_answer,clean
ASSETS=PROJECT/'assets/exam-examples/question-crops/mathematics-2'
TAG=re.compile(r'<\|det\|>(\w+)\s*\[([\d,\s]+)\]<\|/det\|>')
OPT=re.compile(r'^\s*(?:[□☐⃝○◯]|\[\s*\]|-\s*\[\s*\]|\\square|\\Box|[1-9]\.\s|[A-Fa-f][).]\s)\s*')

def blocks(region):
 p=ROOT/'maths-ocr'/(Path(region['path']).stem+'.md');m=p.with_suffix('.json')
 if not p.exists() or not m.exists() or not json.loads(m.read_text()).get('complete'):return None
 s=p.read_text();tags=list(TAG.finditer(s));out=[]
 for i,t in enumerate(tags):
  text=s[t.end():tags[i+1].start() if i+1<len(tags) else len(s)].strip();box=list(map(int,t[2].split(',')))
  normalized=re.sub(r'^\\[\[(]\s*','',text).strip()
  out.append({'type':t[1],'box':box,'text':text,'option':bool(OPT.match(normalized)) and not bool(re.match(r'^\d+\.\s*Question',normalized,re.I)),'option_text':OPT.sub('',normalized).strip(),'region':region})
 return out

assets=[]
checkbox_cache={}
def crop(row,pn,box,name,alt):
 source=row['source'];key=row['source_key'];pagepath=ROOT/'maths-page-renders'/f'{key}_p{pn}.png'
 dims=pdfs[source][pn-1];box=[max(20,box[0]),max(20,box[1]),min(dims.width-20,box[2]),min(dims.height-45,box[3])]
 if box[3]-box[1]<3:return None
 path=ASSETS/f'ga{week(row)}'/f'{name}.png';path.parent.mkdir(parents=True,exist_ok=True)
 if '--review' in sys.argv:
  return {'kind':'image','url':'/'+str(path.relative_to(PROJECT)),'alt':alt}
 with Image.open(pagepath) as im:
  sx=im.width/dims.width;sy=im.height/dims.height;piece=im.crop(tuple(round(v*(sx if i%2==0 else sy)) for i,v in enumerate(box)))
  ink=piece.convert('L').point(lambda v:255 if v<225 else 0).getbbox()
  if ink:piece=piece.crop((max(0,ink[0]-8),max(0,ink[1]-8),min(piece.width,ink[2]+8),min(piece.height,ink[3]+8)))
  piece.save(path)
 url='/'+str(path.relative_to(PROJECT));assets.append({'url':url,'source':source,'page':pn,'box':box})
 return {'kind':'image','url':url,'alt':alt}

def from_det(b):
 
 if 'pdf_box' in b:return b['pdf_box']
 x0,y0,x1,y1=b['region']['box'];a,c,d,e=b['box'];return [x0+(x1-x0)*a/1000,y0+(y1-y0)*c/1000,x0+(x1-x0)*d/1000,y0+(y1-y0)*e/1000]

def week(row):return int(re.search(r'Assignment (\d+)',row['source'])[1])

def getparts(row,start,end,name,alt):
 result=[]
 for pn in range(start[0],end[0]+1):
  p=pdfs[row['source']][pn-1]
  top=start[1] if pn==start[0] else 25;bottom=end[1] if pn==end[0] else p.height-50
  if bottom-top<6:continue
  b=crop(row,pn,[32,top,p.width-30,bottom],f'{name}-p{pn}',alt)
  if b:result.append(b)
 return result

pdfs={};markers={}
def loadpdf(source):
 pdf=pdfplumber.open(source);pdfs[source]=pdf.pages;ms=[]
 for pn,p in enumerate(pdf.pages,1):
  for l in p.extract_text_lines():
   t=l['text'].strip();m=re.match(r'^(\d+)\.\s*Question\b',t,re.I) or re.match(r'^(\d+)\.1\.\s*Answers?\s*:?\s*',t,re.I) or re.match(r'^(\d+)\.2\.\s*Solu(?:tion|ton)\b',t,re.I)
   if m:ms.append({'n':int(m[1]),'kind':'q' if re.match(r'^\d+\.\s*Question',t,re.I) else 'a' if re.search('Answer',t,re.I) else 's','page':pn,'top':l['top'],'bottom':l['bottom']})
 markers[source]=ms

def recover(row):
 source=row['source'];qn=row['question_number'];allb=[]
 for r in row['regions']:
  b=blocks(r)
  if b is None:return None,['Incomplete OCR']
  allb+=b
 ms=markers[source];qmark=next(m for m in ms if m['n']==qn and m['kind']=='q');amark=next(m for m in ms if m['n']==qn and m['kind']=='a');smark=next(m for m in ms if m['n']==qn and m['kind']=='s')
 before=[];answerblocks=[];answerseen=False
 for b in allb:
  heading=re.match(r'^\s*\d+\.1\.?\s*Answers?\s*:?\s*',b['text'],re.I)
  if heading:
   answerseen=True
   if b['text'][heading.end():].strip():answerblocks.append({**b,'text':b['text'][heading.end():].strip()})
   continue
  if answerseen:answerblocks.append(b)
  else:before.append(b)
 opts=[b for b in before if b['option']];answer='\n'.join(b['text'] for b in answerblocks)
 checks=[]
 for rg in row['regions']:
  pn=rg['page'];path=str(ROOT/'maths-page-renders'/f'{row["source_key"]}_p{pn}.png')
  if path not in checkbox_cache:checkbox_cache[path]=checkbox_boxes(path,pdfs[source][pn-1].width)
  for cb in checkbox_cache[path]:
   if any(im['x0']-1<=cb[0]<=im['x1'] and im['top']<=cb[1]<=im['bottom'] for im in pdfs[source][pn-1].images) and cb[2]-cb[0]>=5 and cb[3]-cb[1]>=5 and (pn,cb[1])>(qmark['page'],qmark['bottom']) and (pn,cb[3])<(amark['page'],amark['top']):checks.append((pn,cb,rg))
 if checks:
  clusters=[]
  for c in checks:
   group=next((g for g in clusters if abs(sum(v[1][0] for v in g)/len(g)-c[1][0])<3.5),None)
   if group is None:clusters.append([c])
   else:group.append(c)
  import statistics
  groups=[]
  for g in clusters:
   med=statistics.median(c[1][2]-c[1][0] for c in g)
   g=[c for c in g if c[1][2]-c[1][0]>=.8*med]
   if len(g)>=2:groups.append(g)
  if opts:
   anchor=from_det(opts[0])[0]
   checks=min(groups,key=lambda g:abs(sum(c[1][0] for c in g)/len(g)-anchor)) if groups else []
  elif re.search(r'which.*options|choose.*correct|select all'," ".join(b['text'] for b in before),re.I):
   checks=min(groups,key=lambda g:sum(c[1][0] for c in g)/len(g)) if groups else []
  else:checks=[]
 if len(checks)>=max(2,len(opts)):
  recovered=[]
  for ci,(pn,cb,rg) in enumerate(checks):
   cy=(cb[1]+cb[3])/2
   overlaps=[b for b in before if b['region']['page']==pn and b['type']!='title' and from_det(b)[1]-2<=cy<=from_det(b)[3]+2]
   if overlaps:
    b=min(overlaps,key=lambda b:abs((from_det(b)[1]+from_det(b)[3])/2-cy)).copy();box=from_det(b)
    previous=checks[ci-1][1][3] if ci and checks[ci-1][0]==pn else -1
    above=[a for a in before if a['region']['page']==pn and a['type']!='title' and previous<from_det(a)[1]<box[1] and 0<=box[1]-from_det(a)[3]<4]
    if above:
     a=above[-1];box[1]=from_det(a)[1];b['text']=a['text']+'\n'+b['text']
    # Layout boxes can combine several choices; the checkbox row remains authoritative.
    if ci and checks[ci-1][0]==pn and box[1]<(checks[ci-1][1][1]+checks[ci-1][1][3])/2:box[1]=cb[1]-4
    b['option_text']=OPT.sub('',re.sub(r'^\\[\[(]\s*','',b['text']).strip()).strip()
   else:b={'text':'','option_text':'[Original source option]','region':rg};box=[cb[0],cb[1]-4,580,cb[3]+4]
   b['region']=rg;b['pdf_box']=box;recovered.append(b)
  opts=recovered
 manual_boxes={
  (2,4):[(7,[35,562,451,600]),(7,[35,600,451,640]),(7,[35,640,451,679]),(7,[35,693,451,730]),(7,[35,730,451,750]),(7,[35,750,451,771]),(7,[35,771,451,795])],
  (3,1):[(3,[35,198,465,262]),(3,[35,262,465,334]),(3,[35,334,465,417]),(3,[35,417,465,507])],
  (2,13):[(18,[55,539,541,623]),(18,[55,623,541,708]),(19,[54,43,541,123]),(19,[54,123,541,204])],
  (5,9):[(14,[35,423,528,476]),(14,[35,476,528,532]),(14,[35,532,528,586]),(14,[35,586,528,627])]
 }
 if (week(row),qn) in manual_boxes:
  opts=[{'pdf_box':box,'region':next(r for r in row['regions'] if r['page']==pn),'option_text':f'Original choice {i+1}','text':''} for i,(pn,box) in enumerate(manual_boxes[(week(row),qn)])]
 issues=[]
 promptend=(amark['page'],amark['top']-3)
 if opts:
  first=opts[0];promptend=(first['region']['page'],from_det(first)[1]-4)
 prompt=[]
 for i,r in enumerate(row.get('context_regions',[])):
  b=crop(row,r['page'],r['box'],f'q{qn}-context{i+1}',f'Original shared context for question {qn}.')
  if b:prompt.append(b)
 prompt+=getparts(row,(qmark['page'],qmark['bottom']+5),promptend,f'q{qn}-prompt',f'Original question {qn} from Mathematics 2 graded assignment {week(row)}.')
 row['review_options']=[o['option_text'] for o in opts];row['review_answer']=answer
 q={'type':'','prompt':prompt,'marks':1,'difficulty':'medium'}
 if opts:
  q['options']=[]
  for i,o in enumerate(opts):
   box=from_det(o);pn=o['region']['page'];end=(amark['page'],amark['top']-3)
   if i+1<len(opts):end=(opts[i+1]['region']['page'],from_det(opts[i+1])[1]-4)
   # Keep the complete original option; bounded by the next option or answer heading.
   q['options'].append(getparts(row,(pn,box[1]-3),end,f'q{qn}-option{i+1}',f'Original option {i+1} for question {qn}.'))
  texts=[o['option_text'] for o in opts];parts=re.split(r'(?m)^\s*[•*\-]\s+',answer);parts=[p.strip() for p in parts if p.strip()]
  keys=[]
  for part in parts:
   matches=[i for i,t in enumerate(texts) if canonical(t)==canonical(part)]
   if len(matches)==1:keys+=matches
   else:
    ids=re.findall(r'\boption\s*(\d+)\b',part,re.I)
    if ids:keys += [int(n)-1 for n in ids]
    else:issues.append('Unmatched answer: '+part[:160])
  reviewed=json.loads((ROOT/'maths-reviewed-keys.json').read_text()).get(str(week(row)),{}).get(str(qn))
  if reviewed is not None:
   keys=reviewed;issues=[]
   if any(k>=len(opts) for k in keys):issues.append('Reviewed key exceeds recovered option count')
  keys=sorted(set(keys));multi=len(keys)>1 or 'Answers' in answer
  q['type']='mcq_multi' if len(keys)>1 else 'mcq_single'
  if len(keys)>1:q['correct_answers']=keys
  elif keys:q['correct_answer']=keys[0]
  else:issues.append('No mapped key')
 else:
  value=number_answer(re.sub(r'^\s*[•*\-]\s+','',clean(answer)))
  if value:q.update(type='numerical',numerical_answer=value[0],numerical_tolerance=value[1])
  else:q.update(type='short_answer',acceptable_answers=[clean(answer)]);issues.append('Non-numeric answer without choices')
 # Original worked solution is separate and cannot leak into the attempt prompt.
 q['explanation']=[]
 for i,r in enumerate(row['solution_regions']):
  box=r['box'].copy();box[1]=max(box[1],smark['bottom']+4) if r['page']==smark['page'] else box[1]
  b=crop(row,r['page'],box,f'q{qn}-solution{i+1}',f'Original worked solution for question {qn}.')
  if b:q['explanation'].append(b)
 return q,issues

if __name__=='__main__':
 rows=json.loads((ROOT/'maths-regions.json').read_text());out=[]
 for source in dict.fromkeys(r['source'] for r in rows):loadpdf(source)
 for row in rows:
  if week(row)==1:continue
  q,issues=recover(row);out.append({**row,'question':q,'issues':issues})
 (ROOT/'maths-cropped-candidates.json').write_text(json.dumps(out,indent=2,ensure_ascii=False)+'\n')
 (ROOT/'maths-crop-provenance.json').write_text(json.dumps(assets,indent=2,ensure_ascii=False)+'\n')
 print('CANDIDATES',len(out),'complete',sum(x['question'] is not None for x in out),'mapped',sum(not x['issues'] for x in out))
 for r in out:
  if r['issues']:print('GA',week(r),'Q',r['question_number'],r['issues'])
