from pathlib import Path
import json,re,sys,logging,subprocess,concurrent.futures
import pypdf,pdfplumber
from PIL import Image
sys.path.insert(0,str(Path(__file__).parent))
from extract_batch import ROOT,HEADER,ocr_rows,normalize_headers,source_metadata,context_scope
logging.getLogger('pdfminer').setLevel(logging.ERROR)
OUT=ROOT/'other-regions';OUT.mkdir(exist_ok=True);CACHE=ROOT/'other-page-renders';CACHE.mkdir(exist_ok=True)
BINARY='/Users/tusharrrsingh/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/override/pdftoppm'
manifest=[];jobs={};coverage=[]
for entry in json.loads((ROOT/'source-inventory.json').read_text()):
 source=entry['source'];path=Path(source)
 selected=path.parent.name=='Stats 2' or (path.parent.name=='Stats 1' and 'drive-download' in source) or path.parent.name=='CT'
 if not selected:continue
 data=json.loads((ROOT/'cache'/(entry['key']+'.json')).read_text());key=entry['key']
 opath=ROOT/'cache'/(key+'.ocr.json');ocr={p['page']:p for p in json.loads(opath.read_text())} if opath.exists() else {}
 lines=[];dims={};body=[]
 with pdfplumber.open(source) as pdf:
  for pn,page in enumerate(pdf.pages,1):
   dims[pn]={'width':page.width,'height':page.height}
   if pn==1:continue
   otext='\n'.join(l['text'] for l in ocr.get(pn,{}).get('lines',[]))
   if re.search(r'WHY THIS BOOKLET|BUILT BY STUDENTS',otext,re.I):continue
   body.append(pn)
   if len(re.sub(r'\s','',data['pages'][pn-1]['text']))<150 and pn in ocr:
    rlines=[{**l,'page':pn,'top':l['y']*page.height,'bottom':(l['y']+l['h'])*page.height,'ocr':True} for l in ocr_rows(ocr[pn]['lines'])]
    lines+=normalize_headers(rlines)
   else:
    lines += [{**l,'page':pn,'ocr':False} for l in page.extract_text_lines()]
 markers=[]
 for i,line in enumerate(lines):
  s=line['text'].strip();h=HEADER.match(s)
  if h:markers.append({'kind':'question','number':int(h[1]),'type':h[2],'header':s,'line':i,'page':line['page'],'top':line['top']})
  elif re.match(r'^[^\w]*(?:[LШ]\s*)?(?:Passage\s*/\s*Context|Comprehension)\b',s,re.I):markers.append({'kind':'context','header':s,'line':i,'page':line['page'],'top':line['top']})
 questions=[m for m in markers if m['kind']=='question'];numbers=[m['number'] for m in questions]
 coverage.append({'source':source,'detected_questions':numbers,'missing_numbers':[i for i in range(1,max(numbers,default=0)+1) if i not in numbers]})
 def regions(start,end,label):
  result=[]
  for pn in range(start['page'],end['page']+1):
   top=start['top']-3 if pn==start['page'] else 8
   bottom=end['top']-3 if pn==end['page'] else dims[pn]['height']-38
   if bottom-top<8:continue
   dest=OUT/f'{key}_{label}_p{pn}.png';region={'page':pn,'box':[0,max(0,top),dims[pn]['width'],bottom],'path':str(dest)};result.append(region)
   job=jobs.setdefault((source,key,pn),{'dimensions':dims[pn],'regions':{}});job['regions'][str(dest)]=region
  return result
 for index,start in enumerate(markers):
  if start['kind']!='question':continue
  end=markers[index+1] if index+1<len(markers) else {'page':body[-1],'top':dims[body[-1]]['height']-38}
  qregions=regions(start,end,f'q{start["number"]}');context=[]
  prior=[(i,m) for i,m in enumerate(markers[:index]) if m['kind']=='context']
  if prior:
   ci,ctx=prior[-1];cend=markers[ci+1]
   ctext='\n'.join(l['text'] for l in lines[ctx['line']:cend['line']]);scope=context_scope(ctext)
   if not scope or start['number'] in scope:context=regions(ctx,cend,f'context{ci}')
  subject,section,title=source_metadata(source)
  manifest.append({'source':source,'source_key':key,'subject':subject,'section':section,'quiz_title':title,'question_number':start['number'],'header':start['header'],'regions':qregions,'context_regions':context})
(ROOT/'other-regions.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');(ROOT/'other-region-coverage.json').write_text(json.dumps(coverage,ensure_ascii=False,indent=2)+'\n')
def render(item):
 (source,key,pn),job=item;stem=CACHE/f'{key}_p{pn}';pagefile=stem.with_suffix('.png')
 if all(Path(r['path']).exists() for r in job['regions'].values()):return
 if not pagefile.exists():subprocess.run([BINARY,'-f',str(pn),'-singlefile','-scale-to','2200','-png',source,str(stem)],capture_output=True,check=True)
 with Image.open(pagefile) as im:
  dims=job['dimensions'];sx=im.width/dims['width'];sy=im.height/dims['height']
  for r in job['regions'].values():
   if Path(r['path']).exists():continue
   x0,y0,x1,y1=r['box'];box=(max(0,int(x0*sx)),max(0,int(y0*sy)),min(im.width,int(x1*sx)),min(im.height,int(y1*sy)))
   assert box[2]>box[0] and box[3]>box[1],(source,pn,box)
   im.crop(box).save(r['path'])
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:list(pool.map(render,jobs.items()))
print(len(manifest),'question crops from',len(coverage),'booklets;',sum(bool(c['missing_numbers']) for c in coverage),'sources with header gaps')
