from pathlib import Path
import json,sys,re
from PIL import Image
sys.path.insert(0,str(Path(__file__).parent))
from extract_batch import ROOT,PROJECT,validate,balanced_sizes
rows=json.loads((ROOT/'maths-pa-candidates.json').read_text());papers=[]
for row in rows:
 assert not row['issues'],(row['week'],row['question_number'],row['issues'])
 q=row['question']
 for field in ['prompt','explanation']:
  q[field]=[b for b in q.get(field,[]) if b['kind']!='image' or (PROJECT/b['url'].lstrip('/')).exists()]
 assert q['prompt'] and all('solution' not in b.get('url','') for b in q['prompt']+[b for o in q.get('options',[]) for b in o])
 if (row['week'],row['question_number'])==(2,6):q['explanation'].insert(0,{'kind':'text','value':'The source inline answer 530 conflicts with its equations and worked solution. The quantities are 1 banana, 2 half-cup servings of mozzarella, and 2 avocados, so the intake is 105 + 2×90 + 2×115 = 515 calories.'})
for w in [1,2,3,4,5,8,10]:
 group=sorted([r for r in rows if r['week']==w],key=lambda r:r['question_number']);assert [r['question_number'] for r in group]==list(range(1,len(group)+1));sizes=balanced_sizes(len(group));pos=0
 for part,n in enumerate(sizes,1):
  chunk=group[pos:pos+n];pos+=n
  title=f'Mathematics 2 · Practice Assignment · Week {w}'+(f' · Part {part}' if len(sizes)>1 else '')
  name=f'Mathematics_2_-_Practice_Assignment_-_Week_{w}'+(f'_part{part}' if len(sizes)>1 else '')+'.json'
  paper={'schema_version':'1.1','quiz_title':title,'subject':'Mathematics 2','section':'practice','questions':[r['question'] for r in chunk]};validate(paper)
  path=PROJECT/'bulk_quizzes/Mathematics 2'/name;assert not path.exists() or json.loads(path.read_text())['quiz_title']==title;path.write_text(json.dumps(paper,indent=2,ensure_ascii=False)+'\n');papers.append({'output':str(path),'source':group[0]['source'],'source_questions':[r['question_number'] for r in chunk],'count':n})
assert sum(p['count'] for p in papers)==67
unrecoverable=[]
for w in [6,7,9,11]:
 source=f'/Users/tusharrrsingh/Downloads/all/Maths 2/Maths 2 - Practice Assignment {w} (Week {w}) - Gen-Z IITian - booklet.pdf'
 unrecoverable.append({'source':source,'pages':'3 through the last solution page','reason':'Handwritten worked solutions only. Complete original question stems, full options, and referenced tables or diagrams are absent. Recovering them as questions would require inventing source content.'})
report={'papers':papers,'source_questions':67,'unrecoverable_sources':unrecoverable,'default_fields':{'marks':1,'difficulty':'medium'},'editorial_notes':[{'week':2,'question':6,'note':'Corrected inline530 to515 from source equations and worked solution.'},{'week':1,'question':7,'note':'Algebraic answer stored as short_answer; the correct source factorization is (x-y)(y-z)(x+z).'}, {'week':10,'question':1,'note':'Zero vector is not a direction. At a zero gradient every unit direction maximizes the derivative; selected the original nonzero listed direction. Other directional matches checked from gradients.'},{'week':10,'note':'Internal printed title says Week11; the source filename and course topic identify Week10.'}],'checks':['67 source questions retained without supplements','Every saved paper5to10','All source answer-index bounds and asset existence checked','Inline printed answers redacted from prompt and option crops','Shared original passages attached to all dependent questions','Matrix rows above centered question labels retained','Handwritten worked solutions kept separate from prompts']}
(ROOT/'Mathematics_2_practice_crop_provenance.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
print('SAVED',len(papers),'papers',sum(p['count'] for p in papers),'questions;4 original source gaps')
