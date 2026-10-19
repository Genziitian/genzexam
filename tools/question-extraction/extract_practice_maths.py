from pathlib import Path
import json,re,sys,subprocess
import pdfplumber
from PIL import Image,ImageDraw
sys.path.insert(0,str(Path(__file__).parent))
from extract_batch import ROOT,PROJECT,validate,balanced_sizes
BIN='/Users/tusharrrsingh/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/override/pdftoppm'
OUT=PROJECT/'assets/exam-examples/question-crops/mathematics-2';PAGECACHE=ROOT/'maths-pa-page-renders';PAGECACHE.mkdir(exist_ok=True)
NUMBER=re.compile(r'\[\s*(?:ans(?:wer)?)\s*:\s*([^\]]+)\]',re.I)
pdfs={};lines={};assetmeta=[]

def crop(source,key,w,qn,pn,box,name,role):
 pg=pdfs[source].pages[pn-1];stem=PAGECACHE/f'{key}_p{pn}';path=stem.with_suffix('.png')
 if not path.exists():subprocess.run([BIN,'-f',str(pn),'-singlefile','-scale-to','2200','-png',source,str(stem)],capture_output=True,check=True)
 out=OUT/f'pa{w}'/f'q{qn}-{name}-p{pn}.png';out.parent.mkdir(parents=True,exist_ok=True)
 x0,y0,x1,y1=box
 if y1-y0<5:return None
 if '--review' not in sys.argv:
  with Image.open(path) as im:
   sx=im.width/pg.width;sy=im.height/pg.height;rect=(max(0,round(x0*sx)),max(0,round(y0*sy)),min(im.width,round(x1*sx)),min(im.height,round(y1*sy)));piece=im.crop(rect)
   if role!='solution':
    draw=ImageDraw.Draw(piece)
    for hit in pg.filter(lambda obj:obj['object_type']!='char' or obj.get('size',0)<=35).search(NUMBER):
     if hit['bottom']>=y0 and hit['top']<=y1:draw.rectangle(((hit['x0']-x0-2)*sx,(hit['top']-y0-2)*sy,(hit['x1']-x0+2)*sx,(hit['bottom']-y0+2)*sy),fill='white')
   bbox=piece.convert('L').point(lambda v:255 if v<220 else 0).getbbox()
   if bbox is None:return None
   piece=piece.crop((max(0,bbox[0]-6),max(0,bbox[1]-6),min(piece.width,bbox[2]+6),min(piece.height,bbox[3]+6)));piece.save(out)
 assetmeta.append({'url':'/'+str(out.relative_to(PROJECT)),'source':source,'page':pn,'box':box,'role':role,'redacts_inline_answer':role!='solution'})
 return {'kind':'image','url':'/'+str(out.relative_to(PROJECT)),'alt':f'Original Mathematics 2 practice assignment {w}, question {qn}: {role}.'}

def span(d,qn,start,end,name,role):
 parts=[]
 for pn in range(start[0],end[0]+1):
  p=pdfs[d['source']].pages[pn-1];top=start[1] if pn==start[0] else 20;bottom=end[1] if pn==end[0] else p.height-73
  b=crop(d['source'],d['key'],d['week'],qn,pn,[55,top,p.width-48,bottom],name,role)
  if b:parts.append(b)
 return parts

def main():
 allout=[];markers=[]
 for cache in sorted((ROOT/'cache').glob('*.json')):
  if '.' in cache.stem:continue
  d=json.loads(cache.read_text())
  if '/all/Maths 2/' not in d['source'] or 'Practice' not in d['source']:continue
  w=int(re.search('Assignment (\d+)',d['source'])[1]);d['week']=w
  if w not in [1,2,3,4,5,8,10]:continue
  pdf=pdfplumber.open(d['source']);pdfs[d['source']]=pdf;alllines=[]
  for pn,p in enumerate(pdf.pages,1):
   for l in p.filter(lambda obj:obj['object_type']!='char' or obj.get('size',0)<=35).extract_text_lines():
    if 2<pn<len(pdf.pages) and l['top']<p.height-73:
     # The diagonal watermark is 60pt; retain normal question and math characters only.
     chars=[c for c in p.chars if l['x0']-1<=c['x0']<=l['x1']+1 and l['top']-2<=c['top']<=l['bottom']+2]
     if chars and min(c['size'] for c in chars)>35:continue
     alllines.append({**l,'page':pn})
  starts=[];want=1
  for l in alllines:
   m=re.match(r'^(\d+)\.\s*(?=[A-Z])',l['text'])
   if m and int(m[1])==want and l['x0']<100 and not re.search(r'\bNote\s*:',l['text']):starts.append({**l,'n':want});want+=1
  assert len(starts)>=5,(w,len(starts))
  for qs in starts:
   earlier=[l for l in alllines if l['page']==qs['page'] and qs['top']-38<l['top']<qs['top'] and l['x0']>qs['x0']+25]
   if earlier and ('' in qs['text'] or '' in qs['text'] or 'matrix' in qs['text'] or 'If A' in qs['text']):qs['top']=min(l['top'] for l in earlier)
  for qi,qstart in enumerate(starts):
   qn=qstart['n'];end=starts[qi+1] if qi+1<len(starts) else {'page':len(pdf.pages)-1,'top':pdf.pages[-2].height-73}
   body=[l for l in alllines if (qstart['page'],qstart['top'])<=(l['page'],l['top'])<(end['page'],end['top'])]
   sol=next((l for l in body if re.match(r'^Solution\s*:',l['text'],re.I)),None)
   if sol and any(c in sol['text'] for c in ['','','(cid:12)','(cid:20)']):
    earlier=[l for l in body if l['page']==sol['page'] and sol['top']-38<l['top']<sol['top'] and l['x0']>sol['x0']+35]
    if earlier:sol={**sol,'top':min(l['top'] for l in earlier)}
   if not sol:
    # Handwritten worked solutions are vector paths; their printed question ends with its last normal-size text line.
    printed=[]
    for l in body:
     if l['page']>qstart['page'] and not (w==8 and qn==1):continue
     p=pdf.pages[l['page']-1]
     if len((p.extract_text() or '').strip())<155:continue
     if re.match(r'^\d+$',l['text'].strip()) or len(l['text'].strip())==1:continue
     if l['page']>qstart['page'] and re.match(r'^\d+\s*(?:Numerical|Comprehension)',l['text']):break
     printed.append(l)
    last=printed[-1];sol={'page':last['page'],'top':last['bottom']+8,'bottom':last['bottom']+8}
   pre=[l for l in body if (l['page'],l['top'])<(sol['page'],sol['top'])]
   opts=[l for l in pre if re.match(r'^[⃝○□☐]?\s*Option\s*\d+\s*:',l['text'],re.I)]
   promptend=(opts[0]['page'],opts[0]['top']-3) if opts else (sol['page'],sol['top']-3)
   q={'type':'','prompt':span(d,qn,(qstart['page'],qstart['top']-2),promptend,'prompt','prompt'),'marks':1,'difficulty':'medium'}
   issues=[];answertext='\n'.join(l['text'] for l in body if (l['page'],l['top'])>=(sol['page'],sol['top']))
   if opts:
    q['type']='mcq_multi';q['options']=[]
    for oi,o in enumerate(opts):
     stop=(opts[oi+1]['page'],opts[oi+1]['top']-3) if oi+1<len(opts) else (sol['page'],sol['top']-3)
     q['options'].append(span(d,qn,(o['page'],o['top']-2),stop,f'option{oi+1}','option'))
    keys=json.loads((ROOT/'maths-pa-reviewed-keys.json').read_text())[str(w)][str(qn)]
    if len(keys)==1:q.update(type='mcq_single',correct_answer=keys[0])
    else:q['correct_answers']=keys
    assert all(k<len(opts) for k in keys),(w,qn,len(opts),keys)
   else:
    q['type']='numerical';found=NUMBER.search(' '.join(l['text'] for l in pre))
    if found:
     value=found[1].replace('−','-').strip()
     try:q['numerical_answer']=float(value);q['numerical_tolerance']=.01
     except ValueError:issues.append('Non-numeric inline answer: '+value)
    else:issues.append('No inline answer')
    override={(2,6):515,(4,6):0,(4,7):1,(10,4):6,(10,5):27}.get((w,qn))
    if override is not None:q.update(numerical_answer=override,numerical_tolerance=.01);issues=[]
    if (w,qn)==(1,7):
     from itertools import permutations
     q.update(type='short_answer',acceptable_answers=sorted(set(''.join(a) for factors in [('(x-y)','(y-z)','(z+x)'),('(x-y)','(y-z)','(x+z)')] for a in permutations(factors))));issues=[]
   scope={(1,8):(8,9,10),(2,8):(8,9,10),(3,7):(7,8),(4,8):(8,9),(5,8):(8,9,10),(8,8):(8,9),(10,7):(7,8),(10,9):(9,10)}
   for (sw,first),numbers in scope.items():
    if w!=sw or qn not in numbers:continue
    target=starts[first-1]
    if w==10 and first==9:
     contexts=[l for l in alllines if l['page']==target['page'] and re.search(r'Let L\(x',l['text'])]
    else:contexts=[l for l in alllines if re.search(r'Comprehension Type',l['text'],re.I) and (l['page'],l['top'])<(target['page'],target['top'])]
    assert contexts,(w,qn,'context')
    ctx=contexts[-1];q['prompt']=span(d,qn,(ctx['page'],ctx['top']-2),(target['page'],target['top']-3),'context','context')+q['prompt']
   if (w,qn)==(4,9):q['prompt']=[{'kind':'text','value':'Let S be the span of the four crop-area row vectors for Farmers A, B, C, and D in the passage.'}]+q['prompt']
   q['explanation']=span(d,qn,(sol['page'],sol['top']), (end['page'],end['top']-4), 'solution','solution')
   allout.append({'source':d['source'],'source_key':d['key'],'week':w,'question_number':qn,'question':q,'issues':issues,'prompt_text':'\n'.join(l['text'] for l in pre),'solution_text':answertext,'geometry':{'start':qstart,'solution':sol,'end':end}})
  markers.append({'week':w,'source':d['source'],'questions':len(starts)})
 (ROOT/'maths-pa-candidates.json').write_text(json.dumps(allout,indent=2,ensure_ascii=False)+'\n');(ROOT/'maths-pa-crop-provenance.json').write_text(json.dumps(assetmeta,indent=2,ensure_ascii=False)+'\n');print(json.dumps(markers,indent=2));print('TOTAL',len(allout))

if __name__=='__main__':main()
