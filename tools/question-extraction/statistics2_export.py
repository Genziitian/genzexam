"""Recover native Statistics 2 booklets with answer-free original image crops."""
from pathlib import Path
import json,re,logging,collections,copy,hashlib,unicodedata
import pdfplumber
from PIL import Image
from extract_batch import ROOT,PROJECT,HEADER,balanced_sizes,validate
logging.getLogger('pdfminer').setLevel(logging.ERROR)
ASSETS=PROJECT/'assets/exam-examples/question-crops/statistics-2'
PAPERS=PROJECT/'bulk_quizzes/Statistics 2'
ASSETS.mkdir(parents=True,exist_ok=True);PAPERS.mkdir(parents=True,exist_ok=True)
rows=[q for q in json.loads((ROOT/'candidates.json').read_text()) if q['subject']=='Statistics 2']
regions={(r['source'],r['question_number']):r for r in json.loads((ROOT/'other-regions.json').read_text()) if r['subject']=='Statistics 2'}
gaps=[];provenance=[];assets=[];prepared={}
EXCLUDE={
 ('Feb 2025',3):'No original option contains only the valid independence solution x=1/8; source marks x=1/2 and1/8 although x=1/2 gives negative probabilities.',
 ('Feb 2025',4):'No original option matches the queen/red-card conditional probability. Enumerating red/black queen counts gives (276+2304+276)/325^2 = 2856/105625.',
 ('Oct 2023',5):'Single-choice question has duplicate equal correct values: A=1/9 and C=4/36.',
 ('Oct 2023',16):'Original graph is absent. Source substitutes an approximate verbal graph description inconsistent with the keyed area relation; cropping cannot recover an absent graph.',
 ('Oct 2023',17):'Required original density graph is absent and approximate verbal description cannot determine the stated integral reliably.',
 ('Oct 2025',17):'Question asks one Markov bound but every original option is a pair of unrelated numbers. The source explanation explicitly guesses the missing second task.',
 ('Oct 2025',22):'Single-choice options A and B both display 9/16; option B appends an unspecified different denominator expression. Original alternative is unavailable.',
}
SOLUTIONS={
 ('Feb 2024',11):'Since Z=max(X₁,X₂), independence gives P(Z≤3)=P(X₁≤3)P(X₂≤3)=(3/6)²=1/4. Therefore option A is correct.',
 ('Feb 2024',13):'Production is a nonnegative integer. Exceeding 74 means X≥75. Markov gives P(X≥75)≤E[X]/75=50/75=2/3. Option C is correct.',
 ('Feb 2025',7):'The probabilities sum to 3p+5p=8p=1. Therefore p=1/8, option B.',
 ('Jul 2023',2):'np=2 and np(1−p)=3/2 imply p=1/4 and n=8. Thus P(X=2)=C(8,2)(1/4)²(3/4)⁶=7×3⁶/4⁷, option A.',
 ('Jul 2023',4):'X=4 and U=X+Y−1=8 require Y=5. Independent fair dice give P(X=4,Y=5)=1/36, option C.',
 ('Jul 2023',7):'The columns must be X=0,1,2,3 and rows Y=0,1. Applying f(x,y)=(x²+y)/32 gives row Y=0: 0,1/32,4/32,9/32 and row Y=1: 1/32,2/32,5/32,10/32. Only option D has both these values and the correct Y\\X axis labels. The booklet incorrectly keys A, whose axes are reversed.',
 ('Jul 2025',4):'Var(X)=E[X²]−E[X]²=55−49=6. Chebyshev gives P(|X−7|≥3)≤6/9, so the requested lower bound is 1−6/9=1/3=3/9. Therefore option D is correct; the source key B=5/6 is incorrect.',
 ('Jul 2025',7):'E[X]=∫₀²x(x/2)dx=4/3 and E[X²]=∫₀²x²(x/2)dx=2. Var(X)=2−(4/3)²=2/9, option A.',
 ('Jul 2025',12):'Z=X²+Y−1 takes −1,0,1,3,4, so A is true. P(Z=3|Y=0)=P(X=2|Y=0)=0.1/0.35=2/7, so B is false. C omits possible values. P(Z=4|X=2)=P(Y=1|X=2)=0.15/0.25=0.6, so D is false. Only A is correct; the source key incorrectly includes D.',
 ('Jul 2025',17):'For X uniform on {1,2}, E[X]=1.5 and E[X²]=2.5, so Var(X)=0.25. Var(2X+1)=4Var(X)=1, option C.',
 ('Jun 2022',3):'P(S=2)=0.1; P(S=3)=0.2+0.2=0.4; P(S=4)=0.3+0.1=0.4; P(S=5)=0.1. This is option B.',
 ('Oct 2023',2):'The table gives E[X]=2/3, E[Y]=1, and E[XY]=2/3. Hence Cov(X,Y)=E[XY]−E[X]E[Y]=0.',
 ('Oct 2024',12):'Chebyshev gives P(|X−50|≥20)≤81/400. Consequently P(30≤X≤70)≥1−81/400=319/400, option C.',
 ('Oct 2024',20):'Summing the joint table gives E[X]=0.8, E[Y]=1.05, and E[XY]=0.85. Hence Cov(X,Y)=0.85−0.8×1.05=0.01.',
 ('Oct 2025',13):'Normalization requires k∫₀¹(1+x)dx+k∫₁²(3−x)dx=3k=1. Therefore k=1/3, option A.',
}

def date(row):return re.search(r'Quiz 1 · (.*?) ·',row['quiz_title'])[1]
def txt(value):return {'kind':'text','value':value.strip()}
def prepare(source):
 if source in prepared:return prepared[source]
 pdf=pdfplumber.open(source);lines=[]
 for pn,p in enumerate(pdf.pages,1):
  if pn==1:continue
  for l in p.extract_text_lines():
   if l['top']>p.height-55:continue
   if re.match(r'^(Ecosystem|Gen-Z IITian PYQs|PREVIOUS YEAR QUESTIONS|PAPER:|▶|📚|Source:)',l['text']):continue
   lines.append({**l,'page':pn})
 prepared[source]=(pdf,lines)
 return pdf,lines

def crop(row,ls,label,option=False):
 result=[]
 for pn in sorted(set(l['page'] for l in ls)):
  here=[l for l in ls if l['page']==pn];chars=[c for l in here for c in l['chars'] if not option or c['x0']>=l.get('_option_left',103)]
  if not chars:continue
  box=[min(c['x0'] for c in chars)-2,min(c['top'] for c in chars)-2,max(c['x1'] for c in chars)+2,max(c['bottom'] for c in chars)+2]
  filename=f'{row["source_key"]}_q{row["question_number"]}_{label}_p{pn}.png';dest=ASSETS/filename
  pagepath=ROOT/'other-page-renders'/f'{row["source_key"]}_p{pn}.png';pdf,_=prepare(row['source']);page=pdf.pages[pn-1]
  with Image.open(pagepath) as im:
   sx=im.width/page.width;sy=im.height/page.height
   piece=im.crop((round(box[0]*sx),round(box[1]*sy),round(box[2]*sx),round(box[3]*sy))).convert('RGB')
   if option:
    # The booklet reveals keys with pale green fill; normalize only pale pixels uniformly.
    piece.putdata([(255,255,255) if min(pixel)>=210 else pixel for pixel in piece.getdata()])
   piece.save(dest)
  url='/'+str(dest.relative_to(PROJECT));result.append({'kind':'image','url':url,'alt':f'Original {label.replace("-"," ")} for Statistics 2 question {row["question_number"]}.'})
  assets.append({'url':url,'source':row['source'],'question_number':row['question_number'],'page':pn,'pdf_box':box,'option_background_normalized':option})
 return result

def content(row,ls,label,force=False,option=False):
 if not ls:return []
 groups=[]
 for l in ls:
  kind='code' if re.match(r'^Step\s*\d+\s*[:.]',l['text'],re.I) else 'text'
  if not groups or groups[-1]['kind']!=kind or l['page']!=groups[-1]['lines'][-1]['page'] or l['top']-groups[-1]['lines'][-1]['bottom']>11:
   groups.append({'kind':kind,'lines':[l]})
  else:groups[-1]['lines'].append(l)
 out=[]
 for i,g in enumerate(groups):
  text='\n'.join(l['text'] for l in g['lines']).strip()
  if g['kind']=='code':out.append({'kind':'code','language':'pseudocode','value':text});continue
  chars=[c for l in g['lines'] for c in l['chars'] if not option or c['x0']>=l.get('_option_left',103)]
  mathchars=[c for c in chars if 'Math' in c['fontname']]
  complex=force or (len(mathchars)>=3 and any(not c['text'].isalpha() for c in mathchars)) or any(c['size']<9 for c in mathchars) or ('|' in text and len(g['lines'])>=2)
  if complex:out+=crop(row,g['lines'],f'{label}-{i+1}',option)
  else:
   if option:text=re.sub(r'^[A-D✓✔]\s*','',text)
   text=re.sub(r'[\ue000-\uf8ff]','',text).strip()
   if text:out.append(txt(text))
 return out

def label(line):
 for c in line['chars']:
  if 79<=c['x0']<=97 and c['text'] in 'ABCD✓✔' and ('Bold' in c['fontname'] or 'Symbol' in c['fontname']):return c
 return None

def recover(row):
 d=date(row);n=row['question_number'];q=copy.deepcopy(row['question'])
 if q is None or q['marks']==0:return None,'Administrative subject/formula-sheet acknowledgement; not a scored question.'
 if (d,n) in EXCLUDE:return None,EXCLUDE[d,n]
 pdf,alllines=prepare(row['source']);starts=[i for i,l in enumerate(alllines) if HEADER.match(l['text']) and int(HEADER.match(l['text'])[1])==n]
 assert len(starts)==1,(row['source'],n,starts)
 start=starts[0];end=next((i for i in range(start+1,len(alllines)) if HEADER.match(alllines[i]['text']) or re.match(r'^Passage\s*/\s*Context',alllines[i]['text'],re.I)),len(alllines))
 ls=alllines[start+1:end];ai=next(i for i,l in enumerate(ls) if l['text'].startswith('Answer:'));ei=next((i for i,l in enumerate(ls) if l['text'].startswith('Explanation:')),len(ls))
 before=ls[:ai];choices=[i for i,l in enumerate(before) if label(l)]
 if q['type'].startswith('mcq_'):assert len(choices)==len(q['options']),(d,n,'option labels',len(choices),len(q['options']))
 else:assert not choices,(d,n,choices)
 p=before[:choices[0]] if choices else before
 prompt=[]
 rg=regions[row['source'],n]
 for ri,region in enumerate(rg['context_regions']):
  cls=[l for l in alllines if l['page']==region['page'] and l['top']>=region['box'][1] and l['bottom']<region['box'][3]]
  cls=[l for l in cls if not re.match(r'^Passage\s*/\s*Context',l['text'],re.I)]
  assert not any(l['text'].startswith('Answer:') or HEADER.match(l['text']) for l in cls),(d,n,'leaking context')
  prompt+=content(row,cls,f'context-{ri+1}')
 if (d,n)==('Oct 2022',14):prompt.append(txt('For this question, use a=−3 and b=4, the values satisfying the preceding density-function question.'))
 prompt+=content(row,p,'prompt');q['prompt']=prompt
 if choices:
  q['options']=[]
  for i,x in enumerate(choices):
   optionlines=before[x:choices[i+1] if i+1<len(choices) else len(before)];left=label(before[x])['x1']+4
   optionlines=[{**l,'_option_left':left} for l in optionlines]
   q['options'].append(content(row,optionlines,f'option-{i+1}',option=True))
 if ei<len(ls):q['explanation']=content(row,ls[ei:],'solution')
 else:q.pop('explanation',None)
 if (d,n) in SOLUTIONS:q['explanation']=[txt(SOLUTIONS[d,n])]
 edits=[]
 if (d,n)==('Jul 2023',7):q['correct_answer']=3;edits.append('Corrected A to D: only D labels Y rows and X columns consistently with the defined support.')
 if (d,n)==('Jul 2025',4):q['correct_answer']=3;edits.append('Corrected B to D: Chebyshev lower bound is 1/3, not5/6.')
 if (d,n)==('Jul 2025',12):q['correct_answers']=[0];edits.append('Corrected multi-select key A,D to A: D gives0.15 while conditional probability is0.6.')
 if (d,n)==('Oct 2025',3):edits.append('Two identical source Answer:D lines resolved to the same single correct key.')
 if (d,n)==('Oct 2022',14):edits.append('Attached exact prerequisite constants a=-3,b=4 from the preceding question solution.')
 provenance.append({'source':row['source'],'source_key':row['source_key'],'question_number':n,'edits':edits,'original_key':{k:v for k,v in row['question'].items() if k.startswith('correct_')},'retained_key':{k:v for k,v in q.items() if k.startswith('correct_')}})
 return q,None

def main():
 exports=[]
 for source in sorted(set(r['source'] for r in rows)):
  selected=sorted([r for r in rows if r['source']==source],key=lambda r:r['question_number']);accepted=[]
  for row in selected:
   q,error=recover(row)
   if error:gaps.append({'source':source,'question_number':row['question_number'],'reason':error,'raw_source':row['raw_source']})
   else:accepted.append((row,q))
  sizes=balanced_sizes(len(accepted));cursor=0
  for part,size in enumerate(sizes,1):
   rs=accepted[cursor:cursor+size];cursor+=size;title=selected[0]['quiz_title']+f' · Part {part}'
   paper={'schema_version':'1.1','quiz_title':title,'subject':'Statistics 2','section':'quiz1','questions':[q for r,q in rs]};validate(paper)
   slug=re.sub(r'[^A-Za-z0-9]+','_',selected[0]['quiz_title'].replace(' · ','_-_')).strip('_');slug=slug.replace('_Quiz_1_','_-_Quiz_1_-_')
   dest=PAPERS/f'{slug}_part{part}.json';dest.write_text(json.dumps(paper,ensure_ascii=False,indent=2)+'\n')
   exports.append({'file':str(dest.relative_to(PROJECT)),'source':source,'question_numbers':[r['question_number'] for r,q in rs],'questions':len(rs)})
 report={'source_headers':len(rows),'exported_questions':sum(e['questions'] for e in exports),'paper_count':len(exports),'image_count':len(assets),'exports':exports,'gaps':gaps,'questions':provenance,'assets':assets,'crop_policy':'Exact original mathematical glyphs/table layouts. Option labels/checkmarks/borders cropped out. Only pixels with all RGB channels >=210 set to white for every option to remove correctness tint; darker chart colors preserved.'}
 (ROOT/'statistics2-provenance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k in ['source_headers','exported_questions','paper_count','image_count']},indent=2))
 for g in gaps:print(Path(g['source']).name,g['question_number'],g['reason'])

if __name__=='__main__':main()
