from pathlib import Path
import json,re,sys
from PIL import Image
sys.path.insert(0,str(Path(__file__).parent))
import export_cropped_maths as extraction
from extract_batch import ROOT,PROJECT,validate,balanced_sizes
rows=json.loads((ROOT/'maths-cropped-candidates.json').read_text())
for row in rows:
 if row['question'] is None or row['issues']:
  if row['source'] not in extraction.pdfs:extraction.loadpdf(row['source'])
  row['question'],row['issues']=extraction.recover(row)
 assert row['question'] is not None and not row['issues'],(row['source'],row['question_number'],row['issues'])

def nonblank(b):
 if b['kind']!='image':return True
 with Image.open(PROJECT/b['url'].lstrip('/')) as im:return im.convert('L').point(lambda v:255 if v<225 else 0).getbbox() is not None

for row in rows:
 q=row['question']
 for field in ['prompt','explanation']:q[field]=[b for b in q.get(field,[]) if nonblank(b)]
 for o in q.get('options',[]):o[:]=[b for b in o if nonblank(b)]
 assert q['prompt']
 assert all('solution' not in b.get('url','') for b in q['prompt']+[b for o in q.get('options',[]) for b in o])
 if extraction.week(row)==11 and row['question_number']==1:
  q['explanation']=[{'kind':'text','value':r'Differentiating twice with respect to $x$ gives $f_{xx}=2z+y^5e^{xy}-(yz)^2\sin(xyz)$. Therefore the second option is correct. The source answer line contains an extra $y^2z^2$ term; it has been corrected here.'}]

papers=[]
for w in range(2,12):
 group=sorted([r for r in rows if extraction.week(r)==w],key=lambda r:r['question_number'])
 assert [r['question_number'] for r in group]==list(range(1,max(r['question_number'] for r in group)+1)),w
 sizes=balanced_sizes(len(group));offset=0
 for part,size in enumerate(sizes,1):
  chunk=group[offset:offset+size];offset+=size
  title=f'Mathematics 2 · Graded Assignment · Week {w} · May 2024'+(f' · Part {part}' if len(sizes)>1 else '')
  filename=f'Mathematics_2_-_Graded_Assignment_-_Week_{w}_-_May_2024'+(f'_part{part}' if len(sizes)>1 else '')+'.json'
  paper={'schema_version':'1.1','quiz_title':title,'subject':'Mathematics 2','section':'practice_graded','questions':[r['question'] for r in chunk]}
  validate(paper);path=PROJECT/'bulk_quizzes/Mathematics 2'/filename
  assert not path.exists() or json.loads(path.read_text())['quiz_title']==title
  path.write_text(json.dumps(paper,ensure_ascii=False,indent=2)+'\n')
  papers.append({'output':str(path),'source':group[0]['source'],'source_questions':[r['question_number'] for r in chunk],'count':size})
assert sum(p['count'] for p in papers)==116
provenance={'papers':papers,'source_questions':116,'including_previously_completed_week1_questions':126,'default_fields':{'marks':1,'difficulty':'medium'},'approach':'Exact original PDF crops for complex math, diagrams, matrices, and options. Source answer headings are hard crop boundaries. Worked solutions are separate explanation images. Shared original passages and figures are prepended to every dependent prompt.','editorial_notes':[{'week':6,'question':1,'note':'Source answer says Condition 3 although only Conditions 1 and 2 exist. Source worked solution confirms Condition 2; selected options 2 and 3 (indices1,2).'}, {'week':11,'question':1,'note':'Source answer adds a spurious y²z² term to the second x derivative. Differentiation confirms the second original option. Explanation corrected.'}],'checks':['Every source question number present, including headings with source typos','Every saved paper has5to10questions','All keys are in range and all source image files exist','Prompt and option assets contain no solution images','All original MCQ choices retained; missing OCR markers recovered by image geometry and visual review','No supplements or generated diagrams']}
(ROOT/'Mathematics_2_graded_crop_provenance.json').write_text(json.dumps(provenance,indent=2,ensure_ascii=False)+'\n')
(ROOT/'maths-cropped-candidates.json').write_text(json.dumps(rows,indent=2,ensure_ascii=False)+'\n')
asset_log=json.loads((ROOT/'maths-crop-provenance.json').read_text());asset_log+=extraction.assets;(ROOT/'maths-crop-provenance.json').write_text(json.dumps(asset_log,indent=2,ensure_ascii=False)+'\n')
print('SAVED',len(papers),'papers',sum(p['count'] for p in papers),'questions; with Week1:126 questions')
