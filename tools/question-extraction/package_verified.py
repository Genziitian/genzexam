from pathlib import Path
import json,zipfile,collections
from extract_batch import ROOT,PROJECT,validate
names=['English_1_graded_provenance.json','English_2_graded_provenance.json','Python_recovery_provenance.json','English_practice_provenance.json','Mathematics_2_graded_crop_provenance.json','statistics2-provenance.json','Mathematics_2_practice_crop_provenance.json','statistics1-provenance.json','Computational_Thinking_provenance.json']
papers=set();reports=[]
for name in names:
 p=ROOT/name
 if not p.exists():continue
 reports.append(p);d=json.loads(p.read_text())
 for row in d.get('papers',d.get('outputs',d.get('exports',[]))):
  path=row.get('path',row.get('output',row.get('file')))
  if path:papers.add(Path(path) if Path(path).is_absolute() else PROJECT/path)
papers.add(PROJECT/'bulk_quizzes/Mathematics 2/Mathematics_2_-_Graded_Assignment_-_Week_1_-_May_2024.json')
assets=set();counts=collections.Counter();manifest=[]
for p in sorted(papers):
 d=json.loads(p.read_text());validate(d);counts[d['subject']]+=len(d['questions']);manifest.append({'path':str(p.relative_to(PROJECT)),'subject':d['subject'],'questions':len(d['questions'])})
 for q in d['questions']:
  for blocks in [q['prompt'],q.get('explanation',[]),*q.get('options',[])]:
   for b in blocks:
    if b['kind']=='image':assets.add(PROJECT/b['url'].lstrip('/'))
report={'status':'verified batch; remaining extraction in progress','papers':len(papers),'questions':sum(counts.values()),'by_subject':dict(counts),'assets':len(assets),'files':manifest}
(ROOT/'verified-batch-manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
with zipfile.ZipFile(ROOT/'verified-papers.zip','w',compression=zipfile.ZIP_DEFLATED) as z:
 for p in sorted(papers|assets):z.write(p,p.relative_to(PROJECT))
 for p in reports+[ROOT/'verified-batch-manifest.json']:z.write(p,'reports/'+p.name)
print(json.dumps({k:v for k,v in report.items() if k!='files'}))
