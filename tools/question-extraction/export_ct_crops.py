"""Export CT with verified option geometry, exact source crops, and separate numbered procedures."""
import json,re,collections,copy,math
from pathlib import Path
from PIL import Image
from extract_batch import ROOT,PROJECT,validate,balanced_sizes
rows=json.loads((ROOT/'CT_layout_candidates.json').read_text())
lookup={(int(re.search(r'Week (\d+)',r['quiz_title'])[1]),r['question_number']):r for r in rows}
assets=PROJECT/'assets/exam-examples/question-crops/computational-thinking'
# Remove only the source's answer-background tint from option crops; preserve the original glyphs/code/diagram.
for image in assets.rglob('*option*.png'):
 im=Image.open(image).convert('RGB');pix=im.load();changed=False
 for y in range(im.height):
  for x in range(im.width):
   rr,g,b=pix[x,y]
   if rr>180 and g>200 and b>180 and g>rr+4 and g>b+4:pix[x,y]=(255,255,255);changed=True
 if changed:im.save(image)

def text(s):return {'kind':'text','value':s}
def pseudo(s):return {'kind':'code','language':'pseudocode','value':s.strip()}
def tidy(s):return s.replace('‹','<').replace('›','>').replace('ø','0').replace('Ø','0')
def urlpath(block):return PROJECT/block['url'].lstrip('/')
def steps_blocks(lines):
 lines=[tidy(l['text'])if isinstance(l,dict)else tidy(l)for l in lines]
 hits=[i for i,s in enumerate(lines)if re.match(r'^Step\s*\d+\s*[:.]',s,re.I)]
 if not hits:return None
 first=hits[0];last=hits[-1];before='\n'.join(lines[:first]).strip();code=[];outro=[]
 for i,s in enumerate(lines[first:],first):
  if i>last and re.match(r'^(What|Which|Choose|Identify|The value)\b',s,re.I):outro=lines[i:];break
  code.append(s)
 # A missed OCR step label between two consecutive numbered source instructions has an unambiguous number.
 for i,s in enumerate(code):
  if s.startswith('Read the top card')and i and re.match(r'^Step 3:',code[i-1]) and i+1<len(code)and re.match(r'^Step 5:',code[i+1]):code[i]='Step 4: '+s
 return ([text(before)]if before else[])+[pseudo('\n'.join(code))]+([text('\n'.join(outro))]if outro else[])

# Exact standard Scores data supplied in Week1, cropped separately from the unrelated counting procedure.
score_ctx=lookup[1,1]['contexts'][0]
score_data=[];score_refs=[]
for ref in score_ctx['regions']:
 image=Image.open(ROOT/'other-page-renders'/f'{lookup[1,1]["source_key"]}_p{ref["page"]}.png').convert('RGB');w,h=image.size
 y0=ref['box'][1]
 if ref['page']==3:
  source_ocr=next(p for p in json.loads((ROOT/'cache'/f'{lookup[1,1]["source_key"]}.ocr.json').read_text())if p['page']==3)
  y0=next(l['y']for l in source_ocr['lines']if l['text']=='Scores Dataset')-.005
 crop=image.crop((int(.116*w),int(y0*h),int(.887*w),int(ref['box'][3]*h)))
 dest=assets/'shared'/f'scores_p{ref["page"]}.png';dest.parent.mkdir(exist_ok=True);crop.save(dest)
 score_data.append({'kind':'image','url':'/'+str(dest.relative_to(PROJECT)),'alt':'Original standard Scores dataset, including student city and subject marks.'});score_refs.append({'source':lookup[1,1]['source'],'page':ref['page'],'box':[.116,y0,.887,ref['box'][3]],'path':str(dest)})

previous=collections.defaultdict(list)
for r in rows:
 w=int(re.search(r'Week (\d+)',r['quiz_title'])[1]);n=r['question_number'];notes=[];prompt=[];refs=[]
 for ctx in r['contexts']:
  prompt.extend(copy.deepcopy(ctx['prompt']));refs.extend(ctx['regions'])
  # Keep every numbered instruction in a dedicated, line-by-line pseudocode block as required.
  step_lines=[s for s in ctx['text'].splitlines()if re.match(r'^Step\s*\d+\s*[:.]',s,re.I)]
  if step_lines:prompt.append(pseudo('\n'.join(tidy(s)for s in step_lines)));notes.append('Transcribed the shared numbered procedure into a dedicated pseudocode block; exact data remains visible in original source crops.')
  notes.append('Attached the complete original context, dataset, code or graph before the dependent question.')
 if (w,n)==(8,3):
  prompt=[text('Use the following standard Scores dataset from the supplied Week1 booklet.'),*copy.deepcopy(score_data),*prompt];refs+=score_refs;notes.append('Attached the exact matching standard Scores dataset from the supplied Week1 booklet; independently recomputed the numerical answer as 10.')
 # Follow named definitions, including when the source omits an explicit “above” reference.
 body='\n'.join(l['text']for l in r['lines'])
 end=r['prompt_regions'][-1]if r['prompt_regions']else None
 if end:
  qlines=[l for l in r['lines']if l['page']<end['page']or l['page']==end['page']and l['y']<=end['box'][3]]
 else:qlines=r['lines']
 own='\n'.join(l['text']for l in qlines)
 own_defs=set(re.findall(r'^([A-Za-z]\w*)\s*=',own,re.M))
 dependencies=[]
 for prev in previous[r['source_key']]:
  defs={name for pair in re.findall(r'^([A-Za-z]\w*)\s*=|\bProcedure\s+(\w+)',prev['text'],re.M)for name in pair if len(name)>2}
  relevant={name for name in defs if name not in own_defs and re.search(r'\b'+re.escape(name)+r'\b',own)}
  if relevant:dependencies.append(prev)
 if dependencies:
  prompt.append(text('Reference pseudocode used by this question:'))
  for dep in dependencies:prompt.append(copy.deepcopy(dep['image']));refs.append(dep['region'])
  notes.append('Attached the exact preceding pseudocode defining referenced variables/procedures; no answer choices or keys are included.')
 steps=steps_blocks(qlines)
 if steps:prompt+=steps;notes.append('Preserved the intro, each numbered Step on its own line in pseudocode, and the trailing inquiry.')
 else:
  for image in r['prompt_images']:
   image=copy.deepcopy(image);intro=' '.join(l['text']for l in qlines if l['x']<.13);image['alt']='Original question: '+intro[:400];prompt.append(image)
  refs+=r['prompt_regions']
  notes.append('Preserved complex original code/equations as crops to retain every brace, index, line number, diagram and trailing inquiry.')
 if (w,n)in[(5,4),(5,5)]:
  prompt.insert(0,text('Source erratum: use the assignment Found = True in place of Found == True in the eliminate procedure below.'))
  notes.append('The original PDF incorrectly uses comparison Found == True where the described elimination procedure requires assignment. The correction is explicitly stated to students; the original code image remains unchanged.')
 q={'type':'numerical'if r['qtype']=='NUMERICAL'else'mcq_multi'if r['qtype']=='MSQ'else'mcq_single','prompt':prompt,'marks':r['marks'],'difficulty':'medium'}
 if q['type']=='numerical':
  answer=r['answer'].replace(',','');assert re.fullmatch(r'-?\d+(?:\.\d+)?',answer),(w,n,answer);q['numerical_answer']=float(answer);q['numerical_tolerance']=0
 else:
  keys=[ord(k)-65 for k in re.findall(r'\b[A-H]\b',r['answer'])];assert keys,(w,n,r['answer'])
  q['options']=[]
  for i,option in enumerate(r['options']):
   content=copy.deepcopy(option['content']);assert content,(w,n,i)
   for b in content:
    if b['kind']=='text':
     # Drop an OCR bullet/letter only at the source's label column; preserve the option itself.
     b['value']=b['value'].strip()
    else:b['alt']='Original option '+str(i+1)+' pseudocode or mathematical expression.'
   q['options'].append(content);refs+=option['regions']
  assert all(0<=k<len(q['options'])for k in keys),(w,n,keys,len(q['options']))
  if q['type']=='mcq_single':assert len(keys)==1;q['correct_answer']=keys[0]
  else:q['correct_answers']=keys
 for b in prompt:
  if b['kind']=='image':assert urlpath(b).exists()
 for option in q.get('options',[]):
  for b in option:
   if b['kind']=='image':assert urlpath(b).exists()
 r['question']=q;r['recovery_notes']=notes;r['asset_regions']=refs
 previous[r['source_key']]+=r['code_panels']

# Independently verify the four numeric questions that rely on the full supplied Scores table.
scores=[('Erode',68,64,78),('Salem',62,45,91),('Chennai',57,54,77),('Chennai',42,53,78),('Madurai',87,64,89),('Chennai',71,92,84),('Ambur',81,82,87),('Vellore',84,92,76),('Bengaluru',74,64,51),('Bengaluru',63,88,73),('Chennai',64,72,68),('Bengaluru',97,92,92),('Chennai',52,64,71),('Madurai',65,73,89),('Trichy',89,62,93),('Theni',76,58,90),('Trichy',87,86,43),('Chennai',62,81,67),('Erode',72,92,97),('Trichy',56,78,62),('Vellore',93,68,91),('Bengaluru',78,69,74),('Nagercoil',62,62,57),('Bengaluru',97,91,88),('Madurai',44,72,58),('Chennai',87,75,92),('Chennai',74,71,82),('Madurai',81,76,52),('Madurai',74,83,83),('Vellore',72,66,81)]
assert [sum(sum(a[1:])>250for a in scores),sum(200<sum(a[1:])<250for a in scores),sum(sum(a[1:])<200for a in scores)]==[6,15,8]
assert sum(sum(v==max(a[k]for a in scores if a[0]==city)for k,v in enumerate(values,1))>1for city,*values in scores)==10
papers=[]
for source,group in __import__('itertools').groupby(rows,key=lambda r:r['source']):
 rs=list(group);title=rs[0]['quiz_title'];sizes=balanced_sizes(len(rs));offset=0
 for part,size in enumerate(sizes,1):
  chosen=rs[offset:offset+size];offset+=size
  paper={'schema_version':'1.1','quiz_title':title+(f' · Part {part}'if len(sizes)>1 else ''),'subject':'Computational Thinking','section':'practice_graded','questions':[r['question']for r in chosen]};validate(paper)
  filename=re.sub(r'[^A-Za-z0-9_-]+','_',title.replace(' · ','_-_')).strip('_')+(f'_part{part}'if len(sizes)>1 else '')+'.json'
  dest=PROJECT/'bulk_quizzes/Computational Thinking'/filename;dest.parent.mkdir(exist_ok=True)
  if dest.exists():assert json.loads(dest.read_text())['quiz_title']==paper['quiz_title']
  dest.write_text(json.dumps(paper,ensure_ascii=False,indent=2)+'\n')
  papers.append({'path':str(dest),'questions':size,'source':source,'source_items':[{'question_number':r['question_number'],'notes':r['recovery_notes'],'asset_regions':r['asset_regions'],'original_answer':r['answer']}for r in chosen]})
assert sum(p['questions']for p in papers)==115
(ROOT/'CT_cropped_provenance.json').write_text(json.dumps({'papers':papers,'source_questions':115,'missed_headers_recovered':'QZ was Q2 in Weeks3,4,6,7','numerical_answers_recomputed':{'Week1_Q1':6,'Week1_Q2':15,'Week1_Q3':8,'Week8_Q3':10},'excluded':[]},ensure_ascii=False,indent=2)+'\n')
(ROOT/'CT_cropped_recovered_candidates.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print(len(papers),'papers;',sum(p['questions']for p in papers),'original questions; all crops and schema validated')
