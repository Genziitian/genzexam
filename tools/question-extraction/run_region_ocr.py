from pathlib import Path
import json,time,sys
from mlx_vlm import load,generate
from mlx_vlm.prompt_utils import apply_chat_template
import mlx.core as mx
ROOT=Path(__file__).resolve().parent
MODEL=ROOT.parent/'ocr-tools/models/Unlimited-OCR-4bit'
OUT=ROOT/'maths-ocr';OUT.mkdir(exist_ok=True)
rows=json.loads((ROOT/'maths-regions.json').read_text())
paths=[]
for qn in [1,8]:
 paths += [r['path'] for row in rows if 'Assignment 1 (' in row['source'] and row['question_number']==qn for r in row['regions']]
for row in rows:
 if 'Assignment 1 (' in row['source']:continue
 paths += [r['path'] for r in row.get('context_regions',[])+row['regions']]
paths=list(dict.fromkeys(paths))
model,processor=load(str(MODEL))
prompt=apply_chat_template(processor,model.config,'document parsing.',num_images=1)
for i,path in enumerate(paths,1):
 name=Path(path).stem;out=OUT/(name+'.md');meta=OUT/(name+'.json')
 if out.exists() and meta.exists() and json.loads(meta.read_text()).get('complete'):continue
 started=time.monotonic()
 result=generate(model,processor,prompt,image=[path],max_tokens=4096,temperature=0,verbose=False)
 tokens=getattr(result,'generation_tokens',None)
 info={'image':path,'model':'mlx-community/Unlimited-OCR-4bit','seconds':round(time.monotonic()-started,2),'characters':len(result.text),'generation_tokens':tokens,'complete':bool(result.text.strip()) and (tokens is None or tokens<4096)}
 out.write_text(result.text);meta.write_text(json.dumps(info,indent=2))
 print(i,len(paths),name,info['seconds'],info['characters'],info['complete'],flush=True)
 mx.clear_cache()
print('REGION OCR COMPLETE',len(paths),flush=True)
