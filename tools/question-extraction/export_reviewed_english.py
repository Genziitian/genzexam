from pathlib import Path
import json,sys,re,copy
sys.path.insert(0,str(Path(__file__).parent))
from extract_batch import ROOT,PROJECT,validate
rows=json.loads((ROOT/'candidates.json').read_text())
groups={}
for row in rows:
 if row['subject']=='English 1' and row['section']=='practice_graded':groups.setdefault(row['quiz_title'],[]).append(copy.deepcopy(row))
exported=[];excluded=[]
for title,group in groups.items():
 week=int(re.search(r'Week (\d+)',title)[1]);keep=[];references=[]
 for row in group:
  n=row['question_number'];q=row['question'];notes=[]
  if (week==1 and n in [6,7,8]) or (week==4 and n<=5) or (week==8 and n==10) or (week==12 and n in [8,10]):
   reason='Missing source listening audio' if week in [1,4] else 'Source emphasis/word mismatch' if week==8 else 'Both because and owing to can express cause; source key needs clarification'
   excluded.append({'source':row['source'],'question_number':n,'pages':row['pages'],'reason':reason});continue
  assert q is not None
  if week==1 and n==3:
   q['prompt'][-1]['value']=q['prompt'][-1]['value'].replace('short vowel /u/','short vowel /ʊ/')
   notes.append('Restored short-vowel IPA /ʊ/ from the source explanation.')
  if week==2 and n in [1,2,5]:
   target={1:'courage',2:'worried',5:'red'}[n]
   q['prompt'][-1]['value']=q['prompt'][-1]['value'].replace('the underlined word',f'“{target}”')
   notes.append(f'Replaced lost underline reference with the intended word {target}; source sentence, key and rationale identify the term.')
  if week==6 and n==3:
   q['prompt'][-1]['value']=q['prompt'][-1]['value'].replace('The underlined word','The word “refurbished”')
   notes.append('Made the target word refurbished explicit using the source sentence and explanation.')
  if week==7 and n==2:
   q['prompt'][-1]['value']=q['prompt'][-1]['value'].replace('Which word in the audio means','Which word means')
   notes.append('Removed the audio reference from a self-contained vocabulary question; all original options and answer retained.')
  if week==12 and n==4:
   q['prompt'][-1]['value']=q['prompt'][-1]['value'].rstrip()+'…'
  # All selected questions were reviewed against the extracted stem, options, key and rationale.
  tolerated={'Required emphasis must be recovered from the page','Question appears truncated in source','Listening question lacks an attached playable audio source/transcript'}
  assert not set(row['issues'])-tolerated,(title,n,row['issues'])
  keep.append(q);references.append({'source_question':n,'pages':row['pages'],'notes':row.get('notes',[])+notes})
 paper={'schema_version':'1.1','quiz_title':title,'subject':'English 1','section':'practice_graded','questions':keep}
 validate(paper)
 dest=PROJECT/'bulk_quizzes/English 1'/f'English_1_-_Graded_Assignment_-_Week_{week}.json'
 assert not dest.exists() or json.loads(dest.read_text())['quiz_title']==title
 dest.write_text(json.dumps(paper,indent=2,ensure_ascii=False)+'\n')
 exported.append({'path':str(dest),'questions':len(keep),'source':group[0]['source'],'references':references})
(ROOT/'English_1_graded_provenance.json').write_text(json.dumps({'papers':exported,'excluded':excluded},indent=2,ensure_ascii=False)+'\n')
print(len(exported),'papers;',sum(p['questions'] for p in exported),'questions;',len(excluded),'source items need audio/clarification')
