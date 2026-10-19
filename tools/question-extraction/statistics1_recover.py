"""Source-only Statistics 1 recovery; images retain original diagrams and equations."""
from pathlib import Path
from fractions import Fraction
import json,re,math,logging,collections,copy,subprocess,concurrent.futures
import pdfplumber,numpy as np
from PIL import Image,ImageOps
from extract_batch import ROOT,PROJECT,HEADER,ocr_rows,source_metadata,balanced_sizes,validate,context_scope
logging.getLogger('pdfminer').setLevel(logging.ERROR)
ASSETS=PROJECT/'assets/exam-examples/question-crops/statistics-1';ASSETS.mkdir(parents=True,exist_ok=True)
CACHE=ROOT/'statistics1-page-renders';CACHE.mkdir(exist_ok=True)
PAPERS=PROJECT/'bulk_quizzes/Statistics 1';PAPERS.mkdir(exist_ok=True)
BINARY='/Users/tusharrrsingh/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/override/pdftoppm'
rows=[q for q in json.loads((ROOT/'candidates.json').read_text()) if q['subject']=='Statistics 1']
data={};assets=[];gaps=[];provenance=[]

def text(value):return {'kind':'text','value':value.strip()}
def header(s):
 s=s.translate(str.maketrans('МмСсОо','MmCcOo'))
 s=re.sub(r'^[O0](\d+)(?=\s)','Q'+r'\1',s)
 s=re.sub(r'^Q([OIlZSB]+)(?=\s)',lambda m:'Q'+m[1].translate(str.maketrans('OIlZSB','011258')),s)
 return HEADER.match(s)

def prepare(source,key):
 pdf=pdfplumber.open(source);raw=json.loads((ROOT/'cache'/f'{key}.json').read_text());op=ROOT/'cache'/f'{key}.ocr.json';ocr={p['page']:p for p in json.loads(op.read_text())} if op.exists() else {};lines=[];body=[]
 for pn,p in enumerate(pdf.pages,1):
  if pn==1:continue
  if len(re.sub(r'\s','',raw['pages'][pn-1]['text']))<150:
   ls=ocr_rows(ocr.get(pn,{}).get('lines',[]))
   if re.search(r'WHY THIS BOOKLET|BUILT BY STUDENTS','\n'.join(l['text'] for l in ls),re.I):continue
   ls=[{**l,'top':l['y']*p.height,'bottom':(l['y']+l['h'])*p.height,'x0':l['x']*p.width,'x1':(l['x']+l['w'])*p.width,'ocr':True} for l in ls]
  else:ls=[{**l,'ocr':False} for l in p.extract_text_lines()]
  if not ls:continue
  body.append(pn)
  for l in ls:
   if l['top']>p.height-48:continue
   if re.match(r'^(Ecosystem|Gen-Z IITian|GRADED ASSIGNMENT|SUBJECT$|Statistics for Data|TYPE$|Graded Assignment$|WEEK$|PREVIOUS YEAR QUESTIONS|PAPER:|▶|📚|Source:)',l['text']):continue
   if re.search(r'Video Solutions|Detailed Lecture|YouTube Channel',l['text']):continue
   lines.append({**l,'page':pn})
 markers=[]
 for i,l in enumerate(lines):
  m=header(l['text'])
  if m:markers.append({'kind':'q','n':int(m[1]),'type':m[2],'index':i,**l})
  elif re.match(r'^[^\w]*(?:[LШ]\s*)?(?:Passage\s*/\s*Context|Comprehension)\b',l['text'],re.I):markers.append({'kind':'context','index':i,**l})
 result={'source':source,'key':key,'pdf':pdf,'lines':lines,'markers':markers,'body':body};data[source]=result;return result

def render(job):
 source,key,pn=job;dest=CACHE/f'{key}_p{pn}.png';old=ROOT/'other-page-renders'/dest.name
 if old.exists():return
 if not dest.exists():subprocess.run([BINARY,'-f',str(pn),'-singlefile','-scale-to','2200','-png',source,str(dest.with_suffix(''))],capture_output=True,check=True)

def pagepath(d,pn):
 p=ROOT/'other-page-renders'/f'{d["key"]}_p{pn}.png'
 return p if p.exists() else CACHE/p.name

def circles(d,pn):
 with Image.open(pagepath(d,pn)) as im:
  a=np.asarray(im.convert('RGB'));w,h=im.size;band=a[:,round(w*.135):round(w*.160)].astype(int)
  gray=(band.min(2)>226)&(band.max(2)<252)&((band.max(2)-band.min(2))<10)
  green=(band[:,:,0]<90)&(band[:,:,1]>95)&(band[:,:,1]<200)&(band[:,:,2]<150)&((band[:,:,1]-band[:,:,0])>65)
  mask=(gray|green).sum(1)>max(8,w*.006)
  inds=np.flatnonzero(mask);groups=[]
  for y in inds:
   if not groups or y-groups[-1][-1]>3:groups.append([int(y)])
   else:groups[-1].append(int(y))
  out=[]
  for g in groups:
   if h*.006<len(g)<h*.04:
    y0,y1=g[0],g[-1];out.append({'page':pn,'top':y0/h*d['pdf'].pages[pn-1].height,'bottom':y1/h*d['pdf'].pages[pn-1].height,'center':(y0+y1)/2/h*d['pdf'].pages[pn-1].height})
  return out

def region(d,qn,start,end,label,option=False):
 out=[]
 for pn in range(start[0],end[0]+1):
  p=d['pdf'].pages[pn-1];top=start[1] if pn==start[0] else 25;bottom=end[1] if pn==end[0] else p.height-48
  if bottom-top<3:continue
  x0=p.width*(.165 if option else .115 if 'drive-download' in d['source'] else .075);x1=p.width*(.895 if 'drive-download' in d['source'] else .94)
  if not option and not any(l['page']==pn and l['bottom']>=top and l['top']<=bottom for l in d['lines']) and not any(im['top']<bottom and im['bottom']>top for im in p.images):continue
  with Image.open(pagepath(d,pn)) as im:
   sx,sy=im.width/p.width,im.height/p.height;piece=im.crop((round(x0*sx),round(top*sy),round(x1*sx),round(bottom*sy))).convert('RGB')
   if option:
    a=np.array(piece);a[a.min(2)>=210]=255;piece=Image.fromarray(a)
   ink=ImageOps.invert(piece.convert('L')).point(lambda x:255 if x>35 else 0).getbbox()
   if ink is None:continue
   # Keep diagrams intact; trim only outer empty margins.
   piece=piece.crop((max(0,ink[0]-5),max(0,ink[1]-5),min(piece.width,ink[2]+5),min(piece.height,ink[3]+5)))
   dest=ASSETS/f'{d["key"]}_q{qn}_{label}_p{pn}.png';piece.save(dest)
  url='/'+str(dest.relative_to(PROJECT));out.append({'kind':'image','url':url,'alt':f'Original Statistics 1 question {qn} {label.replace("-"," ")}.'});assets.append({'url':url,'source':d['source'],'question_number':qn,'page':pn,'box':[x0,top,x1,bottom],'option_background_normalized':option})
 return out

def native_labels(ls):
 out=[]
 for i,l in enumerate(ls):
  if l['text']=='CONTEXT' or not re.match(r'^[A-Z✓✔](?:\s|$)',l['text']):continue
  cs=[c for c in l.get('chars',[]) if c['x0']<100 and c['text'] in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ✓✔' and ('Bold' in c['fontname'] or 'Symbol' in c['fontname'])]
  if cs:out.append((i,cs[0]))
 return out

def number(s):
 m=re.match(r'^\s*([-+]?\d+(?:\.\d+)?)\s*(?:\(.*|(?:Range|accepted|range)\b.*|,.*)?$',s,re.I)
 if not m:return None
 val=float(m[1]);tol=.01;t=re.search(r'±\s*(\d+(?:\.\d+)?)',s)
 if t:tol=float(t[1])
 ranges=re.search(r'(?:range|Range)\s*:?\s*\[?\s*([-+]?\d+(?:\.\d+)?)\s*(?:to|,|[-–])\s*([-+]?\d+(?:\.\d+)?)',s)
 if ranges:tol=max(abs(val-float(ranges[1])),abs(val-float(ranges[2])))
 return val,tol

def recover(d,mark,mi):
 end=d['markers'][mi+1]['index'] if mi+1<len(d['markers']) else len(d['lines']);ls=d['lines'][mark['index']+1:end];n=mark['n']
 ans=[l for l in ls if re.match(r'^Answer\s*:',l['text'],re.I)]
 if not ans:return None,'No recoverable answer-key line.'
 a=ans[0];answer=re.sub(r'^Answer\s*:\s*','',a['text'],flags=re.I).strip();before=[l for l in ls if (l['page'],l['top'])<(a['page'],a['top'])]
 if any(re.search(r'hall ticket|ARE YOU SURE|Useful Data|data attachment.*reference',l['text'],re.I) for l in before):return None,'Administrative subject/data-sheet confirmation.'
 marks=re.search(r'(\d+(?:\.\d+)?)\s*marks?',mark['text'],re.I);marks=float(marks[1]) if marks else 1
 if marks==0:return None,'Administrative zero-mark acknowledgement.'
 diff=next((w for w in ['easy','medium','hard'] if w in mark['text']),'medium');q={'type':'','prompt':[],'marks':marks,'difficulty':diff}
 raster=mark['ocr'];opts=[]
 if re.search(r'MCQ|MSQ|MULTI',mark['type'],re.I):
  if raster:
   for pn in range(mark['page'],a['page']+1):opts += [o for o in d['circles'][pn] if (pn,o['center'])>(mark['page'],mark['bottom']) and (pn,o['center'])<(a['page'],a['top'])]
  else:
   opts=[{'page':before[i]['page'],'top':min(before[i]['top'],c['top'])-3,'bottom':c['bottom'],'index':i,'left':c['x1']+4} for i,c in native_labels(before)]
  if len(opts)<2:return None,f'Only {len(opts)} original option markers recovered.'
  # Native GAs place prose and worked answers into extra choice rows; manual limits preserve genuine choices.
  limit=NATIVE_LIMITS.get((week(d),n)) if not raster else None
  if limit:opts=opts[:limit]
  first=opts[0];pend=(first['page'],first['top']-3);q['options']=[]
  for oi,o in enumerate(opts):
   oe=(opts[oi+1]['page'],opts[oi+1]['top']-3) if oi+1<len(opts) else (a['page'],a['top']-6)
   if not raster and limit and oi+1==len(opts):
    extra=native_labels(before)
    if len(extra)>limit:oe=(before[extra[limit][0]]['page'],before[extra[limit][0]]['top']-5)
   if raster:q['options'].append(region(d,n,(o['page'],o['top']-4),oe,f'option-{oi+1}',True))
   else:
    # Native crop horizontal boundary depends on the GA layout, rather than raster page ratios.
    q['options'].append(native_option(d,n,before,o,oe,oi))
  keys=[ord(c.upper())-65 for c in re.findall(r'\b[A-Z]\b',answer,re.I)]
  if not keys or any(k>=len(opts) for k in keys):return None,f'Invalid source key {answer!r} for {len(opts)} options.'
  q['type']='mcq_multi' if re.search(r'MSQ|MULTI',mark['type'],re.I) or len(keys)>1 else 'mcq_single'
  q['correct_answers' if q['type']=='mcq_multi' else 'correct_answer']=keys if q['type']=='mcq_multi' else keys[0]
 else:
  pend=(a['page'],a['top']-6);num=number(answer)
  if num:q.update(type='numerical',numerical_answer=num[0],numerical_tolerance=num[1])
  else:return None,f'No scalar numerical answer: {answer!r}.'
 prior=[(i,m) for i,m in enumerate(d['markers'][:mi]) if m['kind']=='context']
 if prior:
  ci,ctx=prior[-1];ce=d['markers'][ci+1];cl=d['lines'][ctx['index']+1:ce['index']];scope=context_scope('\n'.join(l['text'] for l in cl))
  if not scope or n in scope:q['prompt']+=region(d,n,(ctx['page'],ctx['bottom']+2),(ce['page'],ce['top']-4),'shared-context')
 q['prompt']+=region(d,n,(mark['page'],mark['bottom']+5),pend,'prompt')
 ei=next((i for i,l in enumerate(ls) if re.match(r'^Explanation\s*:',l['text'],re.I)),None)
 if ei is not None:q['explanation']=region(d,n,(ls[ei]['page'],ls[ei]['top']-2),(ls[-1]['page'],ls[-1]['bottom']+2),'solution')
 return q,None

def week(d):
 m=re.search(r'GA Week (\d+)',d['source']);return int(m[1]) if m else 0

def native_option(d,n,ls,o,end,oi):
 out=[]
 for pn in range(o['page'],end[0]+1):
  top=o['top']-2 if pn==o['page'] else 25;bottom=end[1] if pn==end[0] else d['pdf'].pages[pn-1].height-48
  if bottom-top<3:continue
  p=d['pdf'].pages[pn-1]
  with Image.open(pagepath(d,pn)) as im:
   sx,sy=im.width/p.width,im.height/p.height;piece=im.crop((round(o['left']*sx),round(top*sy),round((p.width-40)*sx),round(bottom*sy))).convert('RGB');a=np.array(piece);a[a.min(2)>=210]=255;piece=Image.fromarray(a)
   ink=ImageOps.invert(piece.convert('L')).point(lambda x:255 if x>35 else 0).getbbox()
   if not ink:continue
   piece=piece.crop((max(0,ink[0]-4),max(0,ink[1]-4),min(piece.width,ink[2]+4),min(piece.height,ink[3]+4)));dest=ASSETS/f'{d["key"]}_q{n}_option-{oi+1}_p{pn}.png';piece.save(dest)
  url='/'+str(dest.relative_to(PROJECT));out.append({'kind':'image','url':url,'alt':f'Original option {oi+1} for Statistics 1 question {n}.'});assets.append({'url':url,'source':d['source'],'question_number':n,'page':pn,'box':[o['left'],top,p.width-40,bottom],'option_background_normalized':True})
 return out

NATIVE_LIMITS={(2,12):4,(5,10):5,(7,12):4}

def main():
 import sys
 for source in sorted(set(r['source'] for r in rows)):
  if '--native-only' in sys.argv and 'drive-download' in source:continue
  if '--raster-only' in sys.argv and 'drive-download' not in source:continue
  row=next(r for r in rows if r['source']==source);prepare(source,row['source_key'])
 jobs=[(s,d['key'],pn) for s,d in data.items() for pn in d['body']]
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:list(pool.map(render,jobs))
 for d in data.values():
  if 'drive-download' in d['source']:d['circles']={pn:circles(d,pn) for pn in d['body']}
 if '--inspect' in sys.argv:
  report=[]
  for s,d in data.items():
   for mi,m in enumerate(d['markers']):
    if m['kind']!='q':continue
    q,error=recover(d,m,mi);report.append({'source':s,'n':m['n'],'question':q,'error':error})
  (ROOT/'statistics1-initial.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print('INITIAL',len(report),collections.Counter(r['error'] or 'ok' for r in report));return
 from statistics1_repairs import apply_native
 api=sys.modules[__name__];accepted=[];exports=[]
 for source,d in data.items():
  for mi,m in enumerate(d['markers']):
   if m['kind']!='q':continue
   n=m['n'];candidate=next((r for r in rows if r['source']==source and r['question_number']==n),None);q,error=recover(d,m,mi);notes=[]
   if 'drive-download' not in source:q,error,notes=apply_native(d,n,q,error,candidate,api)
   else:q,error,notes=repair_raster(d,n,q,error)
   if q:
    error=question_error(q)
   if error:gaps.append({'source':source,'question_number':n,'reason':error})
   else:
    accepted.append({'source':source,'source_key':d['key'],'question_number':n,'question':q});provenance.append({'source':source,'question_number':n,'notes':notes})
  if 'drive-download' not in source:
   for extra in extras(d):accepted.append(extra);provenance.append({'source':source,'question_number':extra['question_number'],'notes':['Recovered a genuine compound numerical subquestion that the booklet stored inside an incorrectly formatted MCQ/solution block.']})
 # Preserve weekly papers where possible; combine only authentic fragments below five questions.
 fragments=[]
 for source in data:
  qs=[r for r in accepted if r['source']==source]
  if len(qs)<5:fragments+=qs
  else:exports+=save_papers(qs,source_metadata(source)[2])
 if len(fragments)>=5:exports+=save_papers(fragments,'Statistics 1 · Graded Assignment · Combined Original Fragments')
 elif fragments:gaps.extend({'source':r['source'],'question_number':r['question_number'],'reason':'Fewer than five authentic questions remain in the combined section pool.'} for r in fragments)
 used={b['url'] for e in exports for q in json.loads((PROJECT/e['file']).read_text())['questions'] for field in ['prompt','explanation','options'] for b in flatten_blocks(q.get(field,[])) if b['kind']=='image'}
 report={'sources':list(data),'source_question_headers':sum(m['kind']=='q' for d in data.values() for m in d['markers']),'exported_questions':sum(e['questions'] for e in exports),'paper_count':len(exports),'exports':exports,'questions':provenance,'gaps':gaps,'assets':[a for a in assets if a['url'] in used],'crop_policy':'Original diagrams retained. Source answer-key lines excluded. Choice circles and correctness labels excluded. Only pale pixels with all RGB channels>=210 are whitened uniformly across option crops; dark graph/legend colours remain intact.'}
 suffix='native' if '--native-only' in sys.argv else 'raster' if '--raster-only' in sys.argv else 'all'
 (ROOT/f'statistics1-{suffix}-provenance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('EXPORTED',suffix,report['exported_questions'],'questions',len(exports),'papers',len(gaps),'gaps')

def flatten_blocks(value):
 if isinstance(value,dict):yield value
 elif isinstance(value,list):
  for item in value:yield from flatten_blocks(item)

def question_error(q):
 if not q['prompt']:return 'Original prompt could not be recovered.'
 if q['type'].startswith('mcq_') and any(not opt for opt in q['options']):return 'An original option is empty.'
 if q['type']=='numerical' and not math.isfinite(q.get('numerical_answer',math.nan)):return 'No finite numerical key.'
 return None

def save_papers(qs,title):
 section=source_metadata(qs[0]['source'])[1];sizes=balanced_sizes(len(qs));out=[];cursor=0
 for part,size in enumerate(sizes,1):
  selected=qs[cursor:cursor+size];cursor+=size;fulltitle=title+(f' · Part {part}' if len(sizes)>1 else '');paper={'schema_version':'1.1','quiz_title':fulltitle,'subject':'Statistics 1','section':section,'questions':[r['question'] for r in selected]};validate(paper)
  slug=re.sub(r'[^A-Za-z0-9]+','_',title.replace(' · ','_-_')).strip('_');filename=slug+(f'_part{part}' if len(sizes)>1 else '')+'.json';dest=PAPERS/filename;dest.write_text(json.dumps(paper,ensure_ascii=False,indent=2)+'\n');out.append({'file':str(dest.relative_to(PROJECT)),'questions':len(selected),'source_questions':[{'source':r['source'],'question_number':r['question_number']} for r in selected]})
 return out

def repair_raster(d,n,q,error):
 notes=[]
 if q is None and error=="No scalar numerical answer: 'O'.":
  candidate=next((r for r in rows if r['source']==d['source'] and r['question_number']==n),None)
  if candidate and candidate['question']:
   q=copy.deepcopy(candidate['question']);q.update(type='numerical',numerical_answer=0,numerical_tolerance=.01);error=None;notes.append('Corrected OCR letter O to the explicit/computed zero in the source solution.')
 if not q:return q,error,notes
 name=Path(d['source']).name
 if '15 Mar 2026' in name and n==3:q['correct_answers']=[1,2];q['explanation']=[text('A standard bar chart retains the meaningful order of ordinal categories; a Pareto chart reorders them by frequency. A stacked bar chart can show the association of two categorical variables, and a scatter plot can show the association of two numerical variables. Many categories make a pie chart harder to compare. Therefore B and C are correct.')];notes.append('Corrected source key A,C to B,C using the definitions of ordinal/Pareto/stacked/scatter displays.')
 if '15 Mar 2026' in name and n==16:q['correct_answers']=[0,1,3];q['explanation']=[text('For defined correlation, −1≤r≤1, hence −2<r<2. Covariance and correlation have the same sign because their denominator is positive. Cov(2X,Y)=2Cov(X,Y), while correlation is unitless. Thus A,B,D are true.')];notes.append('Restored omitted correct option B; its printed bounds are −2<r<2.')
 if 'Feb 2024' in name and n==3:q['explanation']=[text('The displayed20marks sum to500, so the mean is25; the median is24. There are11marks strictly greater than20. The modes are10,38,50, so the data is not bimodal. Q1=10 and Q3=38 give IQR28. Correct options are C,D.')];notes.append('Corrected arithmetic in the source explanation: mean25 rather than26.5; keys unchanged.')
 if ('Oct 2023' in name and n==15) or ('15 Mar 2026' in name and n==12) or ('Oct 2025' in name and n==11):
  q['prompt'].append(text('For percentiles, use the nearest-rank method: sort n observations and take the value at rank ceil(n·p) for percentile proportion p.'))
  if 'Oct 2023' in name:q['explanation']=[text('Sorted observations are14,18,20,23,40. Nearest-rank quartiles are the2nd and4th observations:18and23. IQR=23−18=5.')]
  if 'Oct 2025' in name:q['explanation']=[text('Sorted data is8,15,17,19,21,23,25,35. Nearest-rank Q1=15,Q3=23,IQR=8. The upper fence is23+1.5×8=35; no observation is strictly greater than35, so there are0upper outliers.')]
  notes.append('Made the source-compatible percentile convention explicit to avoid dependence on unstated interpolation rules.')
 return q,None,notes

def extras(d):
 w=week(d);items=[]
 def add(n,prompt,answer,tol=.01):items.append({'source':d['source'],'source_key':d['key'],'question_number':n,'question':{'type':'numerical','prompt':[text(prompt)],'numerical_answer':answer,'numerical_tolerance':tol,'marks':1,'difficulty':'medium'}})
 if w==3:
  stem='A factory recorded production over10days as x,x+15,140,150,160,170,180,190,15,20. The mean is128.'
  add('11(i)',stem+' Find x.',120)
  add('11(ii)',stem+' On days5to7, each recorded value exceeds the actual value by15. The values15and20on days9and10should be150and200. Find the corrected average.',155)
 if w==7:
  stem='Among200students,110like Music,130like Sports,and70like both.'
  add('11(i)',stem+' How many like exactly one activity?',100)
  add('11(ii)',stem+' What is the probability that a randomly selected student likes neither activity?',.15)
 if w==8:
  stem='Mr.Chandra creates35%of quiz papers and Ms.Sharma65%. Their passing rates are20%and80%,respectively.'
  add('14(i)',stem+' What is the probability that a student passes a randomly chosen quiz?',.59)
  add('14(ii)',stem+' Given that the student passes, what is the probability that Mr.Chandra created the quiz?',float(Fraction(7,59)))
 if w==11:
  stem='A box contains6red and8blue balls. Four balls are drawn without replacement.'
  add('14(i)',stem+' What is the probability that exactly2are blue? Give two decimal places.',math.comb(8,2)*math.comb(6,2)/math.comb(14,4))
  add('14(ii)',stem+' What is the expected number of blue balls drawn? Give two decimal places.',16/7)
  add('15(ii)','Five products each independently pass inspection with probability0.40. What is the probability that at most one passes? Give three decimal places.',.6**5+5*.4*.6**4,.001)
 return items

if __name__=='__main__':main()
