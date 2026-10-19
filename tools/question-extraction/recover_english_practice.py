"""Source-faithful practice recovery: remove copied LMS feedback, rejoin original options, record gaps."""
from pathlib import Path
import json,re,copy,collections,unicodedata
from extract_batch import ROOT,PROJECT,validate,balanced_sizes
allrows=json.loads((ROOT/'candidates.json').read_text())
rows=[copy.deepcopy(r) for r in allrows if r['subject'] in ['English 1','English 2'] and r['section']=='practice']
lookup={(r['subject'],int(re.search(r'Week (\d+)',r['quiz_title'])[1]),r['question_number']):r for r in rows if not r['quiz_title'].endswith('Advanced')}
def row(sub,w,n):return lookup['English '+str(sub),w,n]
def text(s):return {'kind':'text','value':s}
def squash(s):return re.sub(r'\s+',' ',unicodedata.normalize('NFKC',s)).strip()
def notes(r,s):r.setdefault('recovery_notes',[]).append(s)
def skip(sub,w,nums,reason):
 for n in nums:row(sub,w,n)['excluded_reason']=reason

def fix(sub,w,n,prefix=None,key=None,stem=None,multi=False,why=None):
 r=row(sub,w,n);q=r['question'];original=copy.deepcopy(q);r.setdefault('original_booklet_key',original.get('correct_answer',original.get('correct_answers')));prefix=[] if r.get('_repaired') else (prefix or []);r['_repaired']=True
 options=[' '.join(b.get('value','') for b in option) for option in q.get('options',[])]
 options=[squash(o) for o in options if not re.match(r'^(?:Yes, the answer|No, the answer|Score:|Partially Correct|Tab \d)',o.strip(),re.I)]
 prompt=squash(' '.join(b['value'] for b in q.get('prompt',[])))
 if prefix:
  suffix=squash(' '.join(prefix));assert prompt.endswith(suffix),(sub,w,n,prompt[-200:],suffix)
  prompt=prompt[:-len(suffix)].strip()
 options=prefix+options
 options=[re.sub(r'^[a-d]\)\s*','',o,flags=re.I) for o in options]
 if stem:prompt=stem
 q['prompt']=[text(prompt)];q['options']=[[text(o)] for o in options];q['type']='mcq_multi' if multi else 'mcq_single'
 q.pop('correct_answer',None);q.pop('correct_answers',None)
 if key is None:key=original.get('correct_answer',0)+(len(prefix))
 q['correct_answers' if multi else 'correct_answer']=key if multi else key
 if q.get('marks',0)<=0:q['marks']=1;notes(r,'Assigned one platform mark because the source omits a positive question mark.')
 if original.get('options')!=q['options']:notes(r,'Removed copied learner feedback and restored the original choices embedded at the end of the prompt.')
 if stem:notes(r,'Clarified the original question without adding a replacement exercise.')
 if why:q['explanation']=[text(why)];notes(r,'Source answer/context corrected: '+why)
 return r

# Restore only original options. These first choices were accidentally printed inside the source stems.
prefix1={
 (1,5):['Taught'],
 (2,1):['Adjective','Adverb'],(2,2):['Never','Eaten'],(2,3):['His','Her'],(2,4):['The few','A little'],(2,5):['Puppy','Little'],(2,6):['Time','Place'],(2,7):['About','On'],(2,8):['A','An'],(2,9):['Preposition','Adjective'],
 (3,2):['Could','Should'],
 (4,8):['Pick up','Hang up'],(4,9):['Put out','Shut out'],
 (5,1):['Does'],(5,2):['Where'],(5,5):['Is'],(5,6):['Did go','Went'],(5,7):['Do/ Did','Did/Do'],(5,8):['A plural verb','A singular verb'],(5,9):['Is not','Is'],(5,10):['Will','Are'],
 (6,1):['Important','Less significant'],(6,2):['High-water mark','Annals'],(6,3):['Brilliant','Genius'],(6,4):['Skill to win wars','Self-indulgence'],(6,5):['accomplish','Self-indulgence'],
 (7,1):['Horrible','Unusual'],(7,2):['Noun','Adjective'],(7,3):['She refused to get married','She did not go to parties'],(7,5):['Heroin','Heroine'],
 (9,1):['Slides','Delivery'],(9,2):['Small audience','Specialised audience'],(9,3):['Policy presentations','Business presentations'],(9,4):['Persuading the audience to do something','Impressing the audience'],(9,5):['Signposts which point in the presentation the presenter has reached','Gives a much-needed break to the audience between sections'],(9,6):['1','2'],(9,7):['8-10 members','More than 10 members'],(9,8):['The same degrees','The same technical background'],(9,9):['Abstract','General'],(9,10):["I'd like to note here that…",'I completely disagree with you…'],
 (10,1):['Broadcast','Broadcasted'],(10,2):['A chair','An ostrich'],(10,3):['I have','A good news'],(10,6):['In','To'],(10,7):['About','On'],(10,8):['Long','The Longer'],(10,9):['A','An'],
 (11,6):['Since'],(11,7):['Of'],(11,8):['In'],(11,9):['On'],
 (12,5):['Logical continuity of the sentences'],(12,6):['Add'],(12,7):['Tense inconsistency'],(12,8):['To explain or elaborate'],(12,10):['In contrary','Likewise']}
keys1={1:[1,1,0,1,2,None,None,None,0,1],2:[None,1,2,1,1,2,3,3,2,0],3:[1,None,1,None,1],4:[None]*5+[0,0,0,2,0],5:[2,1,1,1,2,None,1,1,2,3],6:[0,1,3,3,1],7:[1,None,None,None,None],8:[0,0,0,0,1,0,0,0,0,0],9:[None,None,None,0,0,None,0,3,1,3],10:[3,2,1,0,1,2,2,2,0],11:[1,1,None,1,1,2,0,1,2],12:[1,0,1,1,1,2,2,None,1,None]}
for (subject,w,n),r in lookup.items():
 if subject!='English 1':continue
 if w==4 and n<=5:continue
 if w==12 and n==4:continue
 if keys1[w][n-1] is None:continue
 try:fix(1,w,n,prefix1.get((w,n)),keys1[w][n-1])
 except AssertionError:
  # Ligature normalization may leave an isolated punctuation-space discrepancy; compare the exact whitespace-collapsed suffix.
  raise
skip(1,1,[6,7,8],'Listening audio/transcript is absent from the source; a timestamp alone is not a self-contained question.')
skip(1,2,[1],'The required underline is absent in the original PDF, and several different nouns/adjectives in the sentence could be targeted.')
skip(1,3,[2],'More than one modal completion can be grammatical without the missing intended meaning/context.')
skip(1,3,[4],'The supplied meaning of two peas in a pod is imprecise and admits competing interpretations; no unambiguous source key.')
skip(1,4,range(1,6),'The source merges the pause-marking alternatives into the stem and drops a clear question instruction/key; exact choices cannot be recovered reliably.')
skip(1,7,[2],'The original PDF loses the underlining needed to identify the target word; its duplicate source gives a conflicting key.')
skip(1,7,[3,4,5],'These Florence Nightingale comprehension questions depend on missing source audio/transcript.')
skip(1,9,[2,3],'The source gives partial-credit feedback without the complete answer set, and the classification depends on unavailable course criteria.')
skip(1,9,[6],'The recommended font count is course-specific; the duplicate compiled source contains a blank answer and no supporting rule.')
skip(1,11,[3],'Both deals with guns and deals in guns are grammatical with different meanings; no trade/context restriction is supplied.')
skip(1,12,[8],'All listed choices can describe functions of supporting sentences; the source has no defensible unique negative answer.')
fix(1,1,5,prefix1[1,5],2,stem='Which word has the same vowel sound as go?',why='In standard British English, go and close share /əʊ/.')
fix(1,2,9,prefix1[2,9],2,stem='Identify the part of speech of meanwhile in: Tom was talking to Jim; meanwhile, Harry was making lunch.',why='Meanwhile functions as a conjunctive adverb linking the two clauses.')
fix(1,5,6,prefix1[5,6],[0,1],multi=True,stem='Select all grammatically valid completions: I __________ to the gym four times last week.',why='Went is the ordinary simple past. Did go is the grammatical emphatic past. Goed and was go are invalid here.')
fix(1,7,1,prefix1[7,1],1,stem='Which word means not common?',why='Unusual means not usual or common. This vocabulary question can be answered directly from its original choices; the unavailable listening dependency was removed.')
fix(1,9,1,prefix1[9,1],[0,1,2],multi=True,why='The three listed presentation components are slides, delivery, and message; the source asks for three elements rather than one.')
fix(1,12,10,prefix1[12,10],[2,3],multi=True,why='Both owing to and because express cause; neither in contrary nor likewise does so.')
skip(1,1,[9],'The vowel-length classification of the unstressed final vowel in remedy depends on an unstated pronunciation/phonetic convention.')
row(1,8,3)['question']['prompt']=[text('Capital letters mark the primary stress. Select the usual stress pattern of the compound water tank.')]
# Exact passage already present in the supplied compiled source, not an invented reading exercise.
adv=next(r for r in rows if r['quiz_title'].endswith('Advanced') and r['question_number']==47)
passage=squash(adv['question']['prompt'][0]['value']);passage=passage[passage.index('The film Lawrence'):passage.index('The film Lawrence',passage.index('The film Lawrence')+1)]
for n in range(1,6):
 r=row(1,6,n);t=r['question'];stem=t['prompt'][-1]['value']
 if n==1:stem='In the passage, what does high-water mark mean?'
 if n==4:stem='In the passage, what does foible mean?'
 t['prompt']=[text(passage),text(stem)];notes(r,'Attached the complete exact Lawrence passage from the supplied compiled Advanced booklet; made the lost target term explicit.')
mail=next(r for r in allrows if r['subject']=='English 1' and r['section']=='practice_graded' and r['quiz_title'].endswith('Week 12'))['question']['prompt'][0]['value']
for n in [1,2,3]:row(1,12,n)['question']['prompt'].insert(0,text(mail));notes(row(1,12,n),'Attached the exact matching academic-council email from the supplied English1 graded booklet.')
r=row(1,12,4);q=r['question'];q['prompt']=[text(mail),text('Which sentence states the main purpose of the email?')];q['options']=[[text('The council would meet to finalise the task sheet for the year 2022-23.')],[text('I am writing to invite you to the 20th Academic Council meeting of VSTP University, Shillong.')],[text('I request you to confirm your participation so as to reserve the flight tickets.')]];q['type']='mcq_single';q['correct_answer']=1;q['marks']=q.get('marks')or 1;notes(r,'Restored the complete email and rejoined the wrapped invitation option. The invitation is its main purpose.')
row(1,8,4)['question']['prompt']=[text('The plural suffix -s has three pronunciations: /s/, /z/, and /ɪz/. Is this statement true or false?')]
row(1,8,1)['question']['prompt']=[text('In an English word with more than one syllable, the syllable bearing primary stress is more prominent than the other syllables. Is this statement true or false?')]

# English 2: restore the original first one/two choices before correcting demonstrably wrong keys.
prefix2={
 (1,9):['Single inverted comma'],
 (2,1):['How often','When'],(2,2):['Direction','Degree'],(2,3):['What','Why'],(2,4):['Future Indefinite','Future Continuous'],(2,5):['Sarah has already been informed','Sarah have already been informed'],(2,6):['She was extremely happy.','She had an absolutely wonderful day.'],(2,7):['a) Clearly','b) Obviously'],(2,8):['Judgement','Opinion'],(2,9):['There was enough taste','There is additional taste'],
 (3,2):['1 clause','2 clauses'],(3,3):['The hall','Of archives'],(3,4):['The hall','Of archives'],
 (5,1):['Be','Might'],(5,2):['Can','Could'],(5,3):['Will','Read'],(5,4):['Factual elements','Non-factual elements'],(5,6):['Should','Must'],(5,7):['Can','Could'],
 (6,1):['Did she listens to music everyday?','Did she listen to music everyday?'],(6,2):['Did he finished his homework?','Has he finish his homework?'],(6,4):['To be more polite','To give more information'],(6,5):['Whether'],(6,6):['Whether'],(6,9):['Is','See'],
 (8,1):['Monosyllabic word','Polysyllabic word'],(8,3):['Be clear and concise','Be coherent'],
 (10,1):['Only (ii) is correct','Only (iI) and (iv) are correct'],(10,2):['1,2','3,0'],(10,6):['Independent'],(10,8):['Many','Too many'],(10,9):['Zero conditional','First conditional'],
 (11,1):['Blending'],(11,2):['1','2'],(11,3):['Though','Eventually'],(11,4):['Browse, collect, mend','Browse, surf, cycle'],(11,5):['Indian languages','Celtic'],(11,6):['Overused and uninteresting','Boring and soporific'],(11,7):['Latin','French'],(11,8):['Buried','Skipped'],(11,9):['Latin','French'],
 (12,1):['a) Title + first name','b) Title + surname'],(12,2):['a) Hey','b) Hi'],(12,3):['a) I look forward to receiving your response','b) Thank you for your support'],(12,4):['a) Introduction','b) Literature review'],(12,5):['a) Scene','b) Setting'],(12,6):['a) audience','b) crew'],(12,7):['a) Keats','b) Kipling'],(12,8):['a) Organisational barrier','b) Physical/Mechanical barrier'],(12,9):['a) Organise information about yourself','b) Do your research on the organisation']}
keys2={1:[3,1,None,3,None,0,0,1,3],2:[1,1,3,2,2,1,2,2,2],3:[0,0,3,2],5:[1,1,0,1,None,3,2,1],6:[3,2,0,3,0,2,None,None,1,0],8:[None,1,3,1],9:[None]*4,10:[3,None,0,None,1,1,1,3,1],11:[1,1,2,2,3,0,1,3,1],12:[3,3,None,2,1,0,2,1,3]}
for (subject,w,n),r in lookup.items():
 if subject!='English 2':continue
 if keys2[w][n-1] is None:continue
 fix(2,w,n,prefix2.get((w,n)),keys2[w][n-1])
skip(2,1,[3],'No sound or span is marked in a quotation supporting several sound-pattern analyses; no unique defensible figure-of-speech key.')
skip(2,1,[5],'Both truly and exactly can complete the sentence grammatically; no intended semantic distinction is supplied.')
skip(2,5,[5],'The statement mixes competing grammatical analyses of future auxiliaries without specifying the course framework.')
skip(2,6,[7,8],'The exact antecedent sentence for the embedded-clause reference is missing; the available previous sentence does not support the claimed object analysis.')
skip(2,8,[1],'Simple word is not defined by a unique syllable count without its missing writing-course context.')
skip(2,9,[1,2,3,4],'The Ayemenem/Rahel comprehension passage is absent from the supplied source; answering would require an unattached copyrighted reading.')
skip(2,10,[2,4],'The referenced numbered sentence is missing, so its verb/participle count or negation position cannot be verified.')
fix(2,12,3,prefix2[12,3],[0,1],multi=True,stem='Select all appropriate closing lines from the following.',why='Both looking forward to a response and thanking the reader are appropriate closing lines; asking the service cost is not a closing formula.')
for n,stem in [(1,'Select the grammatically correct yes/no question corresponding to: She listens to music every day.'),(2,'Select the grammatically correct yes/no question corresponding to: He has finished his homework.'),(3,'Select the present-tense embedded question corresponding to: Is he a businessman?')]:fix(2,6,n,prefix2.get((6,n)),keys2[6][n-1],stem=stem)
for n,word in [(7,'cliché'),(9,'ricochet')]:row(2,11,n)['question']['prompt']=[text(f'From which language was the English word {word} borrowed?')];notes(row(2,11,n),'Removed an unnecessary orphan sentence-number reference; the original queried word is explicit.')

row(2,10,7)['question']['prompt']=[text('Quantifiers can be used to quantify verbs in large quantities. Is this statement true or false?')]
row(2,3,1)['question']['prompt'].insert(0,text('For this sentence classification, count finite clauses.'))
row(2,3,4)['question']['prompt']=[text('In the clause “The hall of archives is a huge place”, which option is a clause-level adjunct?')]
notes(row(2,3,4),'Clarified that adjunct refers to the clause level, rather than a modifier inside its subject noun phrase.')

# The compiled Advanced booklet repeats the regular practice questions. Link those exact repeats instead of importing them twice.
advanced=[r for r in rows if r['quiz_title'].endswith('Advanced')]
for r in advanced:
 n=r['question_number'];target=None
 if 2<=n<=11:target=(1,n-1)
 elif 12<=n<=21:target=(2,n-11)
 elif 22<=n<=26:target=(3,n-21)
 elif 27<=n<=36:target=(4,n-26)
 elif 37<=n<=46:target=(5,n-36)
 elif 47<=n<=51:target=(6,n-46)
 elif 52<=n<=56:target=(7,n-51)
 elif 57<=n<=66:target=(8,n-56)
 elif 67<=n<=76:target=(9,n-66)
 elif 78<=n<=86:target=(10,n-77)
 elif 87<=n<=91:target=(11,n-86)
 elif 93<=n<=96:target=(11,n-87)
 elif 97<=n<=106:target=(12,n-96)
 if target:
  original=row(1,*target)
  r['duplicate_of']={'source':original['source'],'question_number':original['question_number']}
  if original.get('excluded_reason'):r['excluded_reason']='Compiled duplicate has the same unresolved source problem: '+original['excluded_reason']
  continue
 if n==1:r['excluded_reason']='Administrative assignment cover text, not a question.'
 elif n in [77,92]:
  q=r['question'];q['marks']=q.get('marks')or 1;q['correct_answer']=0 if n==77 else 1
  notes(r,'Distinct original question found only in the supplied compiled Advanced practice booklet.')
 else:raise AssertionError(n)

kept=[r for r in rows if not r.get('duplicate_of') and not r.get('excluded_reason')]
groups=collections.defaultdict(list)
for r in kept:groups[r['subject'],r['quiz_title']].append(r)
fragments=collections.defaultdict(list)
for key in list(groups):
 if len(groups[key])<5:fragments[key[0]].extend(groups.pop(key))
for subject,rs in fragments.items():
 if len(rs)<5:
  small=min((k for k in groups if k[0]==subject),key=lambda k:len(groups[k]));rs.extend(groups.pop(small))
 groups[subject,subject+' · Practice Assignments · Combined PYQ']=rs
papers=[]
for (subject,title),rs in groups.items():
 offset=0;sizes=balanced_sizes(len(rs))
 for part,size in enumerate(sizes,1):
  chosen=rs[offset:offset+size];offset+=size
  paper={'schema_version':'1.1','quiz_title':title+(f' · Part {part}'if len(sizes)>1 else ''),'subject':subject,'section':'practice','questions':[r['question'] for r in chosen]}
  validate(paper)
  filename=re.sub(r'[^A-Za-z0-9_-]+','_',title.replace(' · ','_-_')).strip('_')+(f'_part{part}'if len(sizes)>1 else '')+'.json'
  folder=PROJECT/'bulk_quizzes'/subject;folder.mkdir(parents=True,exist_ok=True);dest=folder/filename
  if dest.exists():assert json.loads(dest.read_text())['quiz_title']==paper['quiz_title']
  dest.write_text(json.dumps(paper,ensure_ascii=False,indent=2)+'\n')
  papers.append({'path':str(dest),'questions':len(chosen),'source_items':[{'source':r['source'],'question_number':r['question_number'],'pages':r['pages'],'notes':r.get('recovery_notes',[]),'original_booklet_key':r.get('original_booklet_key'),'recovered_key':r['question'].get('correct_answer',r['question'].get('correct_answers'))}for r in chosen]})
excluded=[{'source':r['source'],'question_number':r['question_number'],'pages':r['pages'],'reason':r['excluded_reason']}for r in rows if r.get('excluded_reason')and not r.get('duplicate_of')]
duplicates=[{'source':r['source'],'question_number':r['question_number'],'same_as':r['duplicate_of'],'unresolved':r.get('excluded_reason')}for r in rows if r.get('duplicate_of')]
assert sum(p['questions'] for p in papers)+len(excluded)+len(duplicates)==len(rows)
for r in kept:
 q=r['question'];assert len(q['options'])>=2
 assert not any(re.search(r'(?:No, the answer|Yes, the answer|Score:|Partially Correct|Tab \d)',b['value'])for o in q['options']for b in o)
 assert q['type'] in ['mcq_single','mcq_multi']
for p in papers:assert 5<=p['questions']<=10
(ROOT/'English_practice_provenance.json').write_text(json.dumps({'source_candidates':len(rows),'papers':papers,'excluded':excluded,'duplicates':duplicates},ensure_ascii=False,indent=2)+'\n')
(ROOT/'English_practice_recovered_candidates.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print(len(papers),'papers;',sum(p['questions']for p in papers),'questions;',len(excluded),'unresolved/admin;',len(duplicates),'compiled duplicates')
