from pathlib import Path
import time,json,gc,sys
from mlx_vlm import load,generate
from mlx_vlm.prompt_utils import apply_chat_template
import mlx.core as mx
ROOT=Path('/Users/tusharrrsingh/Downloads/exam genz/output/ocr-tools')
OUT=Path('/Users/tusharrrsingh/Downloads/exam genz/output/question-extraction-2026-10-19/ocr-comparison')
OUT.mkdir(exist_ok=True)
models=[('Unlimited-OCR-4bit','document parsing.'),('GLM-OCR-bf16','Text Recognition:')]
if len(sys.argv)>1:models=[m for m in models if m[0]==sys.argv[1]]
for name,prompt in models:
 modelpath=ROOT/'models'/name
 if not (modelpath/'model.safetensors').exists():
  print('Not downloaded yet:',name,flush=True);continue
 started=time.monotonic();model,processor=load(str(modelpath))
 formatted=apply_chat_template(processor,model.config,prompt,num_images=1)
 result=generate(model,processor,formatted,image=['/tmp/maths2-test-page5.png'],max_tokens=4096,temperature=0,verbose=False)
 (OUT/(name+'.md')).write_text(result.text)
 info={'model':name,'image':'/tmp/maths2-test-page5.png','seconds':round(time.monotonic()-started,2),'characters':len(result.text)}
 (OUT/(name+'.json')).write_text(json.dumps(info,indent=2));print(info,flush=True)
 del model,processor,result;gc.collect();mx.clear_cache()
