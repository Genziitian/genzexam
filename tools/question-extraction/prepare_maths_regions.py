from pathlib import Path
import json,re,subprocess,logging,concurrent.futures
import pdfplumber
from PIL import Image
ROOT=Path(__file__).parent.resolve();OUT=ROOT/'maths-regions';OUT.mkdir(exist_ok=True)
BINARY='/Users/tusharrrsingh/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/override/pdftoppm'
logging.getLogger('pdfminer').setLevel(logging.ERROR)
manifest=[];tasks=[]
for c in sorted((ROOT/'cache').glob('*.json')):
 if '.' in c.stem:continue
 d=json.loads(c.read_text())
 if '/all/Maths 2/' not in d['source'] or 'Graded Assignment' not in d['source']:continue
 pages=[];markers=[]
 with pdfplumber.open(d['source']) as pdf:
  for pn,p in enumerate(pdf.pages,1):
   pages.append({'width':p.width,'height':p.height})
   for line in p.extract_text_lines():
    text=line['text'].strip()
    q=re.match(r'^(\d+)\.\s*Question\b',text,re.I)
    a=re.match(r'^(\d+)\.1\.\s*Answers?\s*:?\s*',text,re.I)
    sol=re.match(r'^(\d+)\.2\.\s*Solu(?:tion|ton)\b',text,re.I)
    if re.match(r'^Comprehension\b',text,re.I):
     markers.append({'kind':'context','scope':[int(n) for n in re.findall(r'\d+',text)],'page':pn,'top':line['top'],'bottom':line['bottom']})
    if q or a or sol:markers.append({'kind':'question' if q else 'answer' if a else 'solution','number':int((q or a or sol)[1]),'page':pn,'top':line['top'],'bottom':line['bottom']})
  starts=[x for x in markers if x['kind']=='question']
  assert len(starts)>=5,(d['source'],len(starts))
  for q in starts:
   solution=next((x for x in markers if x['kind']=='solution' and x['number']==q['number']),None)
   answer=next((x for x in markers if x['kind']=='answer' and x['number']==q['number']),None)
   if not solution or not answer:continue
   regions=[]
   for pn in range(q['page'],solution['page']+1):
    top=q['top']-3 if pn==q['page'] else 10
    bottom=solution['top']-3 if pn==solution['page'] else pages[pn-1]['height']-45
    if bottom-top<10:continue
    name=f'{d["key"]}_q{q["number"]}_p{pn}'
    region={'page':pn,'box':[0,top,pages[pn-1]['width'],bottom],'path':str(OUT/(name+'.png'))}
    regions.append(region);tasks.append((d['source'],d['key'],pages[pn-1],region))
   context_regions=[]
   contexts=[m for m in markers if m['kind']=='context' and (m['page'],m['top'])<(q['page'],q['top']) and (not m['scope'] or min(m['scope'])<=q['number']<=max(m['scope']))]
   if contexts:
    ctx=contexts[-1]
    stop=next(m for m in starts if (m['page'],m['top'])>(ctx['page'],ctx['top']))
    for pn in range(ctx['page'],stop['page']+1):
     top=ctx['top']-3 if pn==ctx['page'] else 10
     bottom=stop['top']-3 if pn==stop['page'] else pages[pn-1]['height']-45
     if bottom-top<10:continue
     region={'page':pn,'box':[0,top,pages[pn-1]['width'],bottom],'path':str(OUT/f'{d["key"]}_context{min(ctx["scope"]) if ctx["scope"] else q["number"]}_p{pn}.png')}
     context_regions.append(region);tasks.append((d['source'],d['key'],pages[pn-1],region))
   solution_regions=[]
   later=[m for m in markers if m['kind'] in ['question','context'] and (m['page'],m['top'])>(solution['page'],solution['top'])]
   last_body=max(p['page'] for p in d['pages'] if len(re.sub(r'\s','',p['text']))>150)
   end=later[0] if later else {'page':last_body,'top':pages[last_body-1]['height']-45}
   for pn in range(solution['page'],end['page']+1):
    top=solution['top']-3 if pn==solution['page'] else 10
    bottom=end['top']-3 if pn==end['page'] else pages[pn-1]['height']-45
    if bottom-top<10:continue
    region={'page':pn,'box':[0,top,pages[pn-1]['width'],bottom],'path':str(OUT/f'{d["key"]}_solution{q["number"]}_p{pn}.png')}
    solution_regions.append(region);tasks.append((d['source'],d['key'],pages[pn-1],region))
   manifest.append({'source':d['source'],'source_key':d['key'],'question_number':q['number'],'answer_page':answer['page'],'regions':regions,'context_regions':context_regions,'solution_regions':solution_regions})
(ROOT/'maths-regions.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
cache=ROOT/'maths-page-renders';cache.mkdir(exist_ok=True)
# Render each source page once; crop the exact question+answer region without the worked solution.
page_jobs={}
for source,key,dimensions,region in tasks:page_jobs[(source,key,region['page'])]=(dimensions,[])
for source,key,dimensions,region in tasks:page_jobs[(source,key,region['page'])][1].append(region)
def render(item):
 (source,key,pn),(dims,regions)=item
 stem=cache/f'{key}_p{pn}';path=stem.with_suffix('.png')
 if not path.exists():subprocess.run([BINARY,'-f',str(pn),'-singlefile','-scale-to','2200','-png',source,str(stem)],capture_output=True,check=True)
 with Image.open(path) as im:
  sx=im.width/dims['width'];sy=im.height/dims['height']
  for region in regions:
   if Path(region['path']).exists():continue
   x0,y0,x1,y1=region['box'];box=(max(0,int(x0*sx)),max(0,int(y0*sy)),min(im.width,int(x1*sx)),min(im.height,int(y1*sy)))
   assert box[2]>box[0] and box[3]>box[1]
   im.crop(box).save(region['path'])
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:list(pool.map(render,page_jobs.items()))
print(len(manifest),'question regions from',len(set(r['source'] for r in manifest)),'Mathematics 2 graded booklets')
