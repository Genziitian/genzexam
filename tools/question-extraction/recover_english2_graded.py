from pathlib import Path
import json,re,copy
from extract_batch import ROOT,PROJECT,validate
rows=json.loads((ROOT/'candidates.json').read_text())
source={}
for r in rows:
 if r['subject']=='English 2' and 'GA Week ' in r['source']:
  w=int(Path(r['source']).name.split('Week ')[1].split(' ')[0]);source.setdefault(w,{})[r['question_number']]=r
B=lambda x:{'kind':'text','value':x}
def text(q):return '\n'.join(b['value'] for b in q['prompt'])
def options(q):return [' '.join(b['value'] for b in opt) for opt in q.get('options',[])]
def setopts(q,values,key):
 q['type']='mcq_single';q['options']=[[B(v)] for v in values];q['correct_answer']=key;q.pop('correct_answers',None);q.pop('numerical_answer',None);q.pop('numerical_tolerance',None)
kept={};provenance=[];gaps=[]
def take(w,n,prompt=None,choices=None,key=None,note=None):
 r=source[w][n];q=copy.deepcopy(r['question'])
 if prompt is not None:q['prompt']=[B(prompt)]
 if choices is not None:setopts(q,choices,key)
 elif key is not None:q['correct_answer']=key
 for opt in q.get('options',[]):
  for b in opt:
   b['value']=re.sub(r'\s*Ans\s*[–—-]\s*[a-z]\s*$', '',b['value'],flags=re.I).strip()
 if note:q.pop('explanation',None)
 kept.setdefault(w,[]).append(q)
 provenance.append({'week':w,'source':r['source'],'source_question':n,'pages':r['pages'],'note':note or 'Original wording/options/key checked; formatting cleaned.'})
 return q
# Week 1: word-stress and sound questions do not require recreating an audio clip.
for n in [1,2]:take(1,n)
take(1,3,'Identify the stressed syllable in the word Together.',note='Retained word-stress inquiry; removed unnecessary audio instruction. Source includes the speech transcript.')
take(1,4,'Identify the stressed syllable in the word Represent.',note='Restored shared word-stress instruction from source Q3.')
take(1,5,'Identify the stressed syllable in the word Atmosphere.',note='Restored shared word-stress instruction from source Q3.')
take(1,6)
take(1,7,'How many vowel sounds are there in the word create?',note='Clarified phonetics inquiry as vowel sounds; source key is two.')
take(1,8,choices=['True','False'],key=1,note='Removed explanation text accidentally appended to the False option.')
# Week 2: restore missing inquiry and isolate clauses from source explanations.
for n in range(1,8):take(2,n)
for n,sentence,clause in [(8,'The house where we live has a lot of trees','where we live'),(9,'The patient had died before the doctor came','before the doctor came'),(10,'Whoever sent us this letter should have signed his or her name.','Whoever sent us this letter')]:
 take(2,n,f'In the sentence “{sentence}”, classify the clause “{clause}”.',['Noun clause','Adjectival clause','Adverbial clause'],{8:1,9:2,10:0}[n],note='Restored the inquiry/target clause from the source rationale and removed rationale from options.')
# Week 3: original PDF merges several complete questions into other headers.
take(3,1,'Indicative, subjunctive and imperative are types of:',['verb aspect','verb mood','adverb','verb tense'],1,note='Removed duplicated nested question; retained the second complete source option set and key.')
take(3,3)
take(3,4,'Choose the most polite expression for requesting additional academic support.',note='Made the source functional-language heading into a complete inquiry.')
take(3,5,'Choose the most polite expression for clarifying a doubt.',['Could you please repeat that? I did not understand it the first time.','Repeat that','Can you repeat it?','You are not being very clear'],0,note='Separated original first question from a second question merged into the same header.')
take(3,6,'Choose the most polite expression for requesting lecture notes.',note='Made the source functional-language heading into a complete inquiry.')
take(3,7,'Which of the following is an example of middle clipping?',['gym','flu','phone','gram'],1,note='Recovered complete original Q7 and its flu/influenza rationale embedded under source Q5; Q7 header has unrelated choices.')
take(3,9)
# Week 4.
for n in range(1,6):
 q=take(4,n);q['prompt']=[B(text(q).rstrip(' (\n'))]
# Week 5: source Q8 is embedded in Q5; all ten original questions can be recovered.
for n in [1,2,3,4,5,6,7,9,10]:
 if n in [2,3]:take(5,n,'Identify the modal auxiliary in the following sentence: '+text(source[5][n]['question']),note='Restored shared modal-auxiliary instruction from the end of source Q1.')
 elif n==5:take(5,n,'“Could you shut the door while leaving the room?” Could here denotes:',['Permission','Ability','Request','Suggestion'],2,note='Reassembled original option a Permission from repeated question below the source rationale.')
 elif n in [6,7]:take(5,n,'What does the modal auxiliary in the following sentence denote? '+text(source[5][n]['question']),note='Restored shared inquiry printed under source Q5.')
 else:take(5,n)
q=copy.deepcopy(kept[5][0]);q['prompt']=[B('_____ you join us, please? (formal context)')];setopts(q,['Will','Would'],1);q.pop('explanation',None);kept[5].insert(7,q)
provenance.append({'week':5,'source':source[5][5]['source'],'source_question':8,'pages':[4],'note':'Recovered original Q8 embedded under Q5; formal request takes Would.'})
# Week 6: two stems and their options merged into source Q5.
for n in [1,2,3]:take(6,n)
context='I am not sure when the incident happened.'
take(6,4,context+' Identify the main statement.',note='Restored full sentence from the original source clause options.')
take(6,5,context+' Identify the embedded sentence.',['when the incident happened','I am not sure when','I am not sure','the incident happened'],0,note='Separated source Q5 from embedded Q6 and Q7; source inline key a retained.')
q=copy.deepcopy(kept[6][-1]);q['prompt']=[B("_____ you score well in the exam, I'll buy you gifts.")];setopts(q,['Whether','If','Both whether and if'],1);kept[6].append(q)
provenance.append({'week':6,'source':source[6][5]['source'],'source_question':6,'pages':[4],'note':'Recovered complete original conditional question embedded under Q5; source key b.'})
q=copy.deepcopy(q);q['prompt']=[B('Identify the sentence with a finite subordinate clause:')];setopts(q,['We know that Sarah asks a lot of questions.','He likes to sit quietly.','Sarah hoped to convince John.','I am glad to meet you again.'],0);kept[6].append(q)
provenance.append({'week':6,'source':source[6][5]['source'],'source_question':7,'pages':[4],'note':'Recovered complete original question embedded under Q5; source key a.'})
for n in [8,9,10]:
 if n==9:take(6,n,choices=['food','expensive','cheap','expenditure'],key=1,note='Removed duplicated explanation accidentally appended to option d; article an selects expensive.')
 else:take(6,n)
# Week 7 and 8: remove clearly unrelated source fragments, retain all sound asks.
for n in range(1,6):
 if n==1:take(7,n,'Which of the following is NOT appreciated in a group discussion?',note='Removed unrelated fill-in blanks spliced into the original stem.')
 elif n==5:take(7,n,'The expression “To put that another way…” indicates ________.',['Stating an opinion','Expressing disagreement','Reformulating','Making a suggestion'],2,note='Removed unrelated quantifier exercise spliced into option d.')
 else:take(7,n)
for n in [1,2,3,4,6,7,8,9,10]:take(8,n)
# Week 9: original narrative passage/audio absent; retain self-contained vocabulary only.
week9={3:("What is the meaning of acceptability?",['Ability to like someone','The quality of being allowed or tolerated','Ability to accept everything','All of the above'],1),5:("What is the meaning of celestial?",['Relating to home','Relating to heaven','Relating to war','Relating to water'],1),6:("In “You have been stranded thousands of miles from home”, what does stranded mean?",['Left alone','Tortured','Confused'],0),8:("In “It became the foundation of his life’s work and legacy”, what does legacy mean?",['A set of property or values left after one’s departure.','A treat by a leader','An unseen treasure.'],0),10:("What is the meaning of intrigued?",['Irritated','Interested','Involved'],1)}
for n,(prompt,choices,key) in week9.items():take(9,n,prompt,choices,key,note='Recovered original options embedded in prompt; removed learner feedback. Vocabulary question is self-contained; corrected erroneous source key where necessary.')
# Week 10: first two real options appear in prompt, learner feedback masquerades as options.
w10={1:('“All assignments were submitted.” This sentence is in the passive voice.',['True','False'],0),2:('“The displayed ornaments glittered in the dazzling lights.” The verb in this sentence is:',['Displayed','Glittered','Dazzling','All of the above'],1),3:('In “The displayed ornaments glittered in the dazzling lights”, there are ___ finite verbs and ___ participles.',['0,3','3,0','1,2','2,1'],2),4:('Negative sensitive elements are:',['Anyone','Anybody','Anything','All of the above'],3),5:('“They did not tell anyone about their plan” is a negative sentence.',['True','False'],0),6:('Choose the correct reported speech: “Who did you see?” Prema asked.',['Prema asked me who I saw','Prema asked me who I had seen','Prema told me who I have seen','Prema told me who I had seen'],1),7:('Choose the indirect speech of “I haven’t seen him.”',['He said he didn’t see him','He said that he hadn’t seen him','He told that he didn’t seen him','He told that he hadn’t see him'],1),8:('This proposal is ___ better than the previous one.',['As much','Much','Much of','Not many'],1),9:('Ours is a small class. We don’t have ___ students.',['Much','Many','Large','Any'],1),10:('If they are innocent, they will be acquitted. This is a ___ sentence.',['Zero conditional','First conditional','Second conditional','Mixed conditional'],1)}
for n,(prompt,choices,key) in w10.items():take(10,n,prompt,choices,key,note='Recovered real source choices from prompt; removed feedback and corrected source key. Q3 includes its exact sentence context.')
# Week 11.
w11={1:('‘-s’ and ‘-ies’ in dogs and babies are:',['Plural markers','Morphemes','Both of the above','None of the above'],2),2:('Reduction of a word to one of its parts is called:',['Blending','Clipping','Borrowing'],1),3:('Which of the following is an example of middle clipping?',['Gym','Flu','Phone','Gram'],1),4:('“He did not break down when he heard the grave news. Rather, he became very stoic and appeared to bear it quite normally.” The connecting word/phrase is:',['And','Became','Rather','There is no connecting word/phrase'],2),5:('“He did not break down when he heard the grave news. Rather, he became very stoic and appeared to bear it quite normally.” Here, rather means the same as instead.',['True','False'],0),6:('English has many prefixes and suffixes from Greek and Latin.',['True','False'],0),7:('Bungalow, loot, and pyjamas are English words from:',['Latin','French','Indian languages','Spanish'],2),8:('“The business tycoon who made billions with his hotel chain Resorta, has been found dead.” Here tycoon means:',['A headman','A billionaire','A CEO','A wealthy and powerful person'],3),9:('Tycoon is a word borrowed from which language?',['Latin','French','Italian','Japanese'],3),10:('“The music club auditions allow candidates to have a karaoke to the song they’ll be singing.” Here karaoke means:',['Lyrics','Sheet music','Pre-recorded backing tracks','Funny noises'],2)}
for n,(prompt,choices,key) in w11.items():take(11,n,prompt,choices,key,note='Recovered original options and removed learner feedback; corrected source keys. References to another question were made self-contained.')
# Week 12: missing email context prevents Q1–3; seven independent asks remain.
w12={4:('If the recipient is unknown, what should be the best salutation in a professional mail?',['Dear Sir/Madam','Hello','Hey','Dear'],0),5:('If you are arguing a conclusion, what kind of research report are you writing?',['analytical','expository','prepository','argumentative'],3),6:('What are forms and styles of speech called?',['Barriers','Instrumentalities','Scene writing','Stage setting'],1),7:('What does A in the acronym SPEAKING refer to?',['Act sequence','Arbitration','Acceptance of the audience','Audience'],0),8:('Hierarchy is a/an:',['Organisational barrier','Physical/Mechanical barrier','Language/Semantic barrier','Personal barrier'],0),9:('Which of the following are challenges when you face an interview?',['Anxiety','Inadequate preparation','Frequent distractions','All of the above'],3),10:('Bad translation is a/an:',['Organisational barrier','Physical/Mechanical barrier','Language/Semantic barrier','Personal barrier'],2)}
for n,(prompt,choices,key) in w12.items():take(12,n,prompt,choices,key,note='Recovered real source choices from prompt, removed feedback, and corrected source key where necessary.')
for w,ns,reason in [(1,[9,10],'Audio-dependent pause choices; audio not bundled.'),(3,[10],'Source prefix classification ambiguous; not replaced with a new exercise.'),(8,[5],'Source answer All of the above includes avoiding uncommon words, which does not uniquely define length limits.'),(9,[1,2,4],'Referenced narrative passage absent.'),(9,[7,9],'Listening fill-in requires absent original audio.'),(9,list(range(11,21)),'Exact duplicate of Q1–10.'),(12,[1,2,3],'Referenced email context absent from source.')]:
 for n in ns:gaps.append({'source':next(iter(source[w].values()))['source'],'source_question':n,'reason':reason})
outputs=[]
for w,questions in sorted(kept.items()):
 paper={'schema_version':'1.1','quiz_title':f'English 2 · Graded Assignment · Week {w}','subject':'English 2','section':'practice_graded','questions':questions}
 validate(paper)
 for q in questions:
  assert not re.search(r'No, the answer|Yes, the answer|Score:|Ans\s*[–-]',json.dumps(q,ensure_ascii=False))
 out=PROJECT/'bulk_quizzes/English 2'/f'English_2_-_Graded_Assignment_-_Week_{w}.json';out.write_text(json.dumps(paper,ensure_ascii=False,indent=2)+'\n');outputs.append({'path':str(out),'questions':len(questions)})
(ROOT/'English_2_graded_provenance.json').write_text(json.dumps({'outputs':outputs,'source_questions':provenance,'gaps':gaps,'references':[{'source':'https://warwick.ac.uk/fac/soc/al/repository/staff/richardskeith/se2lecturenotesrichards_k/','used_for':'Hymes SPEAKING: Act sequence and Instrumentalities'}],'rules':['No invented supplements or replacement choices','Only original recoverable questions retained','Original malformed option boundaries and demonstrably wrong keys repaired with review notes','Missing source narrative/email/audio reported rather than fabricated']},ensure_ascii=False,indent=2)+'\n')
assert len(outputs)==12 and sum(x['questions'] for x in outputs)==96
print('ENGLISH 2 GRADED',len(outputs),'papers',sum(x['questions'] for x in outputs),'questions')
