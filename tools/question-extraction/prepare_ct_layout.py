from pathlib import Path
import json,re,collections,math
from PIL import Image
from extract_batch import ROOT,ocr_rows,normalize_headers,HEADER,context_scope,source_metadata
ASSETS=ROOT.parents[1]/'assets/exam-examples/question-crops/computational-thinking';ASSETS.mkdir(parents=True,exist_ok=True)
entries=[e for e in json.loads((ROOT/'source-inventory.json').read_text())if '/CT/'in e['source']]
manifest=[]
def runs(values,gap=3):
 result=[]
 for y in values:
  if result and y-result[-1][-1]<=gap+1:result[-1].append(y)
  else:result.append([y])
 return result

def markers(im):
 im=im.convert('RGB');w,h=im.size
 ys=[]
 for y in range(h):
  hits=sum(im.getpixel((x,y))in [(242,244,245),(22,162,74)]for x in range(int(w*.13),int(w*.16)))
  if max(8,int(w*.006))<=hits<=int(w*.026):ys.append(y)
 circles=[]
 for rr in runs(ys):
  if w*.008<=rr[-1]-rr[0]<=w*.04 and len(rr)>=w*.008:circles.append({'top':rr[0]/h,'bottom':rr[-1]/h,'center':((rr[0]+rr[-1])/2)/h})
 dark=[]
 for y in range(h):
  hits=sum(im.getpixel((x,y))==(29,29,46)for x in range(int(w*.13),int(w*.88),max(1,w//300)))
  if hits>45:dark.append(y)
 panels=[{'top':rr[0]/h,'bottom':rr[-1]/h}for rr in runs(dark,5)if rr[-1]-rr[0]>h*.012]
 return circles,panels

def savecrop(im,key,pn,label,y0,y1,x0=.116,x1=.887,white=False):
 w,h=im.size;box=(int(x0*w),int(max(0,y0)*h),int(x1*w),int(min(.94,y1)*h));assert box[3]>box[1]
 result=im.crop(box).convert('RGB')
 if white:
  pix=result.load()
  for y in range(result.height):
   for x in range(result.width):
    r,g,b=pix[x,y]
    if min(r,g,b)>180:pix[x,y]=(255,255,255)
 dest=ASSETS/key/f'{label}_p{pn}.png';dest.parent.mkdir(exist_ok=True);result.save(dest)
 return {'kind':'image','url':'/'+str(dest.relative_to(ROOT.parents[1])),'alt':label.replace('_',' ')}, {'page':pn,'box':[x0,y0,x1,y1],'path':str(dest),'background_normalized':white}

for e in entries:
 key=e['key'];pages=json.loads((ROOT/'cache'/f'{key}.ocr.json').read_text());lines=[];ims={};circs={};panels={}
 for p in pages:
  pn=p['page'];file=ROOT/'other-page-renders'/f'{key}_p{pn}.png'
  if pn==1 or not file.exists():continue
  ims[pn]=Image.open(file).convert('RGB');circs[pn],panels[pn]=markers(ims[pn])
  for line in normalize_headers([{**l,'text':re.sub(r'^QZ(?=\s|$)','Q2',l['text']),'page':pn,'ocr':True}for l in ocr_rows(p['lines'])]):
   if line['y']<.94:lines.append(line)
 found=[]
 for i,l in enumerate(lines):
  s=l['text'].strip();h=HEADER.match(s)
  if h:found.append({'kind':'question','number':int(h[1]),'qtype':h[2].upper(),'index':i,'page':l['page'],'top':l['y']})
  elif re.match(r'^[\W_]*(?:[LШ]\s*)?(?:Passage\s*/\s*Context|Comprehension)\b',s,re.I):found.append({'kind':'context','index':i,'page':l['page'],'top':l['y']})
 contexts=[];code_history=[]
 for mi,m in enumerate(found):
  end=found[mi+1]if mi+1<len(found)else{'index':len(lines),'page':max(ims),'top':.94}
  ls=lines[m['index']+1:end['index']]
  if m['kind']=='context':
   text='\n'.join(l['text']for l in ls);images=[];refs=[]
   for pn in range(m['page'],end['page']+1):
    if pn not in ims:continue
    top=m['top']+.018 if pn==m['page']else.035;bottom=end['top']-.008 if pn==end['page']else.937
    if bottom-top<.01:continue
    img,ref=savecrop(ims[pn],key,pn,f'context{len(contexts)}',top,bottom)
    images.append(img);refs.append(ref)
   contexts.append({'scope':sorted(context_scope(text)),'text':text,'prompt':images,'regions':refs,'before_question':next((f['number']for f in found[mi+1:]if f['kind']=='question'),None)})
   continue
  answer=next((l for l in ls if re.match(r'^Answer\s*:',l['text'],re.I)),None)
  if not answer:
   manifest.append({'source':e['source'],'source_key':key,'question_number':m['number'],'issue':'Missing source answer line'});continue
  als=next(i for i,l in enumerate(ls)if l is answer);ls=ls[:als]
  lastpage=answer['page'];limit=answer['y']-.015
  options=[]
  for pn in range(m['page'],lastpage+1):
   lo=m['top']+.018 if pn==m['page']else.035;hi=limit if pn==lastpage else.937
   for c in circs.get(pn,[]):
    if lo<c['center']<hi:options.append({'page':pn,**c})
  first=options[0]if options else{'page':lastpage,'top':limit}
  promptimages=[];promptrefs=[];history=[]
  for pn in range(m['page'],first['page']+1):
   top=m['top']+.022 if pn==m['page']else.035;bottom=first['top']-.013 if pn==first['page']else.937
   if bottom-top<.01:continue
   img,ref=savecrop(ims[pn],key,pn,f'q{m["number"]}_prompt',top,bottom)
   promptimages.append(img);promptrefs.append(ref)
   for j,b in enumerate(panels.get(pn,[])):
    if b['top']>=top and b['bottom']<=bottom+.01:
     ci,cr=savecrop(ims[pn],key,pn,f'q{m["number"]}_code{j}',b['top']+.003,b['bottom']-.003,.13,.886)
     history.append({'image':ci,'region':cr,'text':'\n'.join(l['text']for l in ls if l['page']==pn and b['top']<=l['y']<=b['bottom'])})
  opts=[]
  for oi,o in enumerate(options):
   nxt=options[oi+1]if oi+1<len(options)else{'page':lastpage,'top':limit+.007};content=[];refs=[];texts=[]
   for pn in range(o['page'],nxt['page']+1):
    lo=o['top']-.005 if pn==o['page']else.035;hi=nxt['top']-.008 if pn==nxt['page']else.937
    if hi-lo<.005:continue
    opanels=[b for b in panels.get(pn,[])if b['top']>lo-.02 and b['bottom']<hi+.015]
    ptexts=[l for l in ls if l['page']==pn and lo<=l['y']<=hi and l['x']>.128]
    for li,l in enumerate(ptexts):
     s=l['text']
     if li==0 and l['x']<.159:s=re.sub(r'^'+chr(65+oi)+r'\s+|^[•✓✔V]\s*','',s,flags=re.I)
     if s.strip()==chr(65+oi)or not s.strip():continue
     texts.append(s)
    if opanels:
     for j,b in enumerate(opanels):
      img,ref=savecrop(ims[pn],key,pn,f'q{m["number"]}_option{oi+1}_code{j}',b['top']+.002,b['bottom']-.002,.178,.878)
      content.append(img);refs.append(ref)
    elif ptexts:
     # Formula text is kept as a crop so OCR cannot change matrix subscripts or logical symbols.
     complex_=any(re.search(r'\[[^\]]*\]|[<>!=]|matrix|[+*/]|\bD\[',l['text'])for l in ptexts)
     if complex_:
      top=min(l['y']for l in ptexts)-.002;bottom=max(l['y']+l['h']for l in ptexts)+.002
      img,ref=savecrop(ims[pn],key,pn,f'q{m["number"]}_option{oi+1}',top,bottom,.163,.88,True)
      content.append(img);refs.append(ref)
     else:content.append({'kind':'text','value':'\n'.join(texts).strip()});texts=[]
   opts.append({'content':content,'regions':refs,'text':'\n'.join(texts)})
  header=lines[m['index']]['text'];marks=re.search(r'(\d+)\s*marks?',header,re.I)
  selected=[]
  qtext='\n'.join(l['text']for l in ls)
  for ctx in contexts:
   active=(not ctx['scope']or m['number']in ctx['scope'])
   named=any(name.lower()in qtext.lower()and name.lower()in ctx['text'].lower()for name in ['Scores','Words','Shopping Bills','books','Paragraph'])
   if active or named:selected.append(ctx)
  value=re.sub(r'^Answer\s*:\s*','',answer['text'],flags=re.I).strip().translate(str.maketrans({'А':'A','В':'B','С':'C','Е':'E','Н':'H','О':'O'}))
  dependencies=[]
  if re.search(r'above|previous|constructed|computed|earlier|following matrices|common data',qtext,re.I):
   for h in code_history:
    defs=re.findall(r'^([A-Za-z]\w*)\s*=|\bProcedure\s+(\w+)',h['text'],re.M)
    names={n for pair in defs for n in pair if len(n)>1}
    if any(re.search(r'\b'+re.escape(n)+r'\b',qtext)for n in names):dependencies.append(h)
  manifest.append({'source':e['source'],'source_key':key,'question_number':m['number'],'quiz_title':source_metadata(e['source'])[2],'header':header,'qtype':m['qtype'],'marks':int(marks[1])if marks else 1,'prompt_images':promptimages,'prompt_regions':promptrefs,'options':opts,'answer':value,'question_text':qtext,'lines':ls,'contexts':selected,'dependencies':dependencies,'code_panels':history})
  code_history+=history
(ROOT/'CT_layout_candidates.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(len(manifest),'questions;',collections.Counter((r.get('qtype'),len(r.get('options',[])))for r in manifest))
