from pathlib import Path
import json,time,sys,gc
ROOT=Path(__file__).resolve().parent
MODEL=ROOT.parent/'ocr-tools/models/GLM-OCR-bf16'
for _ in range(900):
 if (MODEL/'model.safetensors').exists():break
 time.sleep(2)
else:raise RuntimeError('GLM model download did not complete')
from mlx_vlm import load,generate
from mlx_vlm.prompt_utils import apply_chat_template
import mlx.core as mx
model,processor=load(str(MODEL))
prompt=apply_chat_template(processor,model.config,'Text Recognition:',num_images=1)
# Compare an actual matrix page before using the second engine for solution transcription.
check=generate(model,processor,prompt,image=['/tmp/maths2-test-page5.png'],max_tokens=4096,temperature=0,verbose=False)
compare=ROOT/'ocr-comparison';compare.mkdir(exist_ok=True)
(compare/'GLM-OCR-bf16.md').write_text(check.text)
print('GLM MATRIX TEST',len(check.text),flush=True)
rows=json.loads((ROOT/'maths-regions.json').read_text())
paths=list(dict.fromkeys(r['path'] for row in rows if 'Assignment 1 (' not in row['source'] for r in row.get('solution_regions',[])))
OUT=ROOT/'maths-solution-ocr';OUT.mkdir(exist_ok=True)
for i,path in enumerate(paths,1):
 out=OUT/(Path(path).stem+'.md');meta=out.with_suffix('.json')
 if out.exists() and meta.exists() and json.loads(meta.read_text()).get('complete'):continue
 started=time.monotonic();result=generate(model,processor,prompt,image=[path],max_tokens=8192,temperature=0,verbose=False)
 tokens=getattr(result,'generation_tokens',None)
 info={'image':path,'model':'mlx-community/GLM-OCR-bf16','seconds':round(time.monotonic()-started,2),'characters':len(result.text),'generation_tokens':tokens,'complete':bool(result.text.strip()) and (tokens is None or tokens<8192)}
 out.write_text(result.text);meta.write_text(json.dumps(info,indent=2));print(i,len(paths),Path(path).stem,info['seconds'],info['characters'],info['complete'],flush=True);mx.clear_cache()
print('SOLUTION OCR COMPLETE',len(paths),flush=True)
