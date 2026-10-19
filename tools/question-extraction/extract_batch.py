"""Extract booklet questions without inventing missing prompts, options, or answers."""
from pathlib import Path
import json, re, math, collections, textwrap, hashlib, logging

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[1]
SUBJECTS = {'Python':'Python','CT':'Computational Thinking','Maths 1':'Mathematics 1','Maths 2':'Mathematics 2','Stats 1':'Statistics 1','Stats 2':'Statistics 2','Eng1':'English 1','Eng 2':'English 2'}
HEADER = re.compile(r'^Q(\d+)\s+(MCQ|MSQ|MULTI-SELECT|NUMERICAL|NUMERIC|NAT|SA|SHORT.ANSWER|TRUE\s*/\s*FALSE)\b(.*)', re.I)
OPTION = re.compile(r'^(?:([A-Z])(?:\s+|$)|([✓✔])\s*)(.*)$')
ANSWER = re.compile(r'^Answer\s*:\s*(.*)',re.I)
FOOTER = re.compile(r'\s*Ecosystem\s*[—–-].*',re.I)
NOISE = re.compile(r'^(?:E\s*X\s*A\s*M\s*\.|GENZIITIAN\.IN/|Y\s*O\s*U\s*T\s*U\s*B\s*E$|Gen-Z IITian|Source:|[▶📚]|Video Solutions|Detailed Lecture)',re.I)
INLINE_KEY = re.compile(r'\[\s*Ans(?:wer)?\s*[:.\-]?\s*([^\]]+)\]|\bAns\s*[-:]\s*([a-z](?:\s*[,;]\s*[a-z])*)(?=\s|$)',re.I)

def clean(line):
    return FOOTER.sub('',line.replace('\u00a0',' ')).rstrip()

def joined(lines):
    return '\n'.join(l['text'].strip() for l in lines if l['text'].strip()).strip()

def context_scope(text):
    numbers={int(n) for n in re.findall(r'\bQ\s*(\d+)',text,re.I)}
    for a,b in re.findall(r'\bQ\s*(\d+)\s*(?:[-–]|to|through)\s*Q?\s*(\d+)',text,re.I):numbers.update(range(int(a),int(b)+1))
    return numbers

def block(text,kind='text',language=None):
    b={'kind':kind,'value':text.strip()}
    if language:b['language']=language
    return b

def blocks(lines, subject):
    result=[];buf=[];kind=None
    def flush():
        if not buf:return
        value='\n'.join(buf)
        if kind=='code':
            result.append(block(textwrap.dedent(value).strip(),'code','python' if subject=='Python' else 'pseudocode'))
        else:
            result.append(block(value))
        buf.clear()
    for line in lines:
        s=line['text']
        if s.strip() in ['CONTEXT','Context:']:continue
        k='code' if line.get('code') or re.match(r'^\s*Step\s*\d+\s*[:.]',s,re.I) else 'text'
        if k!=kind:flush();kind=k
        buf.append(s)
    flush()
    # Procedure steps can be wrapped or mashed into a single text run in older sources.
    converted=[]
    for b in result:
        value=b['value']
        hits=list(re.finditer(r'\bStep\s*(\d+)\s*[:.]\s*',value,re.I))
        if len(hits)>=2:
            intro=value[:hits[0].start()].strip()
            if intro:converted.append(block(intro))
            steps=[];outro=''
            for i,m in enumerate(hits):
                body=value[m.end():hits[i+1].start() if i+1<len(hits) else len(value)].strip()
                if i+1==len(hits):
                    tail=re.search(r'(?<=[.\n])\s*(What\b|Which\b|Choose\b|Identify\b|The value of\b)[\s\S]*',body,re.I)
                    if tail:outro=body[tail.start():].strip();body=body[:tail.start()].strip()
                steps.append(f'Step {m.group(1)}: {body}')
            converted.append(block('\n'.join(steps),'code','pseudocode'))
            if outro:converted.append(block(outro))
        else:converted.append(b)
    return converted

def source_metadata(source):
    p=Path(source);subject=SUBJECTS[p.parent.name]
    if 'Quiz 1' in p.name:
        section='quiz1';suffix=re.sub(r'^Statistics [12] - Quiz 1 - ','',p.stem)
        suffix=re.sub(r' - (?:genz_iitian|Gen-Z IITian)(?: - booklet)?$','',suffix,flags=re.I)
        suffix=suffix.replace('(','').replace(')','')
        title=f'{subject} · Quiz 1 · '+suffix.replace(' - ',' · ')
    else:
        week=re.search(r'(?:Week\s*|Assignment\s*)(\d+)',p.name,re.I)
        week=int(week.group(1)) if week else None
        practice=bool(re.search(r'\bPA\b|Practice',p.name,re.I))
        section='practice' if practice else 'practice_graded'
        title=f'{subject} · '+('Practice Assignment' if practice else 'Graded Assignment')+f' · Week {week}'
        if p.name.startswith('Advanced'):title+=' · Advanced'
    return subject,section,title

def load_lines(data):
    key=data['key'];source=Path(data['source'])
    enriched=ROOT/'cache'/f'{key}.lines.json'
    if enriched.exists():return json.loads(enriched.read_text())
    # Monospaced source glyph positions preserve actual Python indentation.
    if source.parent.name=='Python':
        import pdfplumber
        logging.getLogger('pdfminer').setLevel(logging.ERROR)
        result=[]
        with pdfplumber.open(source) as pdf:
            for pno,page in enumerate(pdf.pages,1):
                lines=page.extract_text_lines()
                for ln in lines:
                    mono=[c for c in ln['chars'] if re.search('Consolas|Courier|Mono',c['fontname'],re.I)]
                    s=clean(ln['text'])
                    code=len(mono)>len(ln['chars'])*.5
                    if code and mono:
                        unit=sorted(c['x1']-c['x0'] for c in mono)[len(mono)//2]
                        indent=max(0,round((ln['x0']-83.25)/unit)) if unit else 0
                        s=' '*indent+s
                    if s.strip():result.append({'text':s,'page':pno,'code':code,'ocr':False})
        enriched.write_text(json.dumps(result,ensure_ascii=False));return result
    ocrpath=ROOT/'cache'/f'{key}.ocr.json'
    ocrpages={p['page']:p for p in json.loads(ocrpath.read_text())} if ocrpath.exists() else {}
    result=[]
    for page in data['pages']:
        page_ocr=ocrpages.get(page['page'],{})
        page_text='\n'.join(l['text'] for l in page_ocr.get('lines',[]))
        if page['page']==1 or re.search(r'WHY THIS BOOKLET|BUILT BY STUDENTS',page_text,re.I):
            continue
        if page['page'] in ocrpages and len(re.sub(r'\s','',page['text']))<150:
            for line in ocr_rows(ocrpages[page['page']]['lines']):
                s=clean(line['text'])
                if s.strip():result.append({**line,'text':s,'page':page['page'],'ocr':True})
        else:
            result.extend({'text':clean(s),'page':page['page'],'ocr':False} for s in page['text'].splitlines() if clean(s).strip())
    return result

def ocr_rows(lines):
    rows=[]
    for line in sorted(lines,key=lambda l:(l['y']+l['h']/2,l['x'])):
        center=line['y']+line['h']/2
        if rows and abs(center-rows[-1][0]['y']-rows[-1][0]['h']/2)<.45*min(line['h'],rows[-1][0]['h']):rows[-1].append(line)
        else:rows.append([line])
    result=[]
    for row in rows:
        row.sort(key=lambda l:l['x']);text=row[0]['text']
        for a,b in zip(row,row[1:]):
            gap=b['x']-a['x']-a['w']
            text+=('   ' if gap>.025 else ' ')+b['text']
        result.append({**row[0],'text':text,'confidence':min(l['confidence'] for l in row)})
    return result

def normalize_headers(lines):
    normalized=[];i=0
    types=re.compile(r'^(MCQ|MSQ|MULTI-SELECT|NUMERICAL|NUMERIC|NAT|SA)\b',re.I)
    while i<len(lines):
        line=lines[i];s=line['text'].strip()
        match=re.fullmatch(r'[QO0](\d+)(?:\s+(.*))?',s)
        if match and line.get('ocr'):
            tail=match[2] or ''
            if types.match(tail):line={**line,'text':f'Q{match[1]} {tail}'}
            elif not tail and i+1<len(lines) and types.match(lines[i+1]['text'].strip()):
                i+=1;line={**line,'text':f'Q{match[1]} '+lines[i]['text'].strip()}
        normalized.append(line);i+=1
    return normalized

def option_parts(lines):
    matches=[]
    for i,l in enumerate(lines):
        if l.get('code'):continue
        m=OPTION.match(l['text'].strip())
        lower=re.match(r'^([a-z])\)\s*(.*)',l['text'].strip())
        if lower:matches.append((i,lower[1].upper(),False,lower[2]))
        elif m:matches.append((i,m.group(1),bool(m.group(2)),m.group(3)))
    # Only a contiguous A, B, C... sequence (checks replace letters) is an option list.
    for start in range(len(matches)):
        seq=[]
        for match in matches[start:]:
            if match[2] or match[1]==chr(65+len(seq)):seq.append(match)
            else:break
        if len(seq)>=2 and start+len(seq)==len(matches):
            opts=[]
            for j,(idx,letter,check,txt) in enumerate(seq):
                end=seq[j+1][0] if j+1<len(seq) else len(lines)
                opts.append(([{**lines[idx],'text':txt}] if txt else [])+lines[idx+1:end])
            return lines[:seq[0][0]],opts,seq
    return lines,[],[]

def parse_question(chunk,subject):
    header=HEADER.match(chunk[0]['text'].strip());num=int(header[1]);rawtype=header[2].upper();headtail=header[3]
    refs={'question_number':num,'pages':sorted(set(l['page'] for l in chunk))}
    lines=[{**l,'text':clean(l['text'])} for l in chunk[1:] if not NOISE.match(l['text'].strip()) and clean(l['text']).strip()]
    anspos=next((i for i,l in enumerate(lines) if ANSWER.match(l['text'].strip())),None)
    if anspos is None:return None,refs,['No source answer key']
    before=lines[:anspos];ans=ANSWER.match(lines[anspos]['text'].strip())[1].strip()
    explanation=lines[anspos+1:]
    if explanation and explanation[0]['text'].startswith('Explanation:'):
        explanation[0]={**explanation[0],'text':explanation[0]['text'][12:].strip()}
    else:
        explanation=[]
    reasons=[];notes=[]
    if any(l.get('ocr') for l in chunk):reasons.append('Raster source: OCR transcription needs visual verification')
    if subject.startswith('English') and re.search(r'(?:Yes|No),?\s+the answer is (?:in)?correct|\bScore\s*:\s*\d|\bTab\s+\d',joined(before),re.I):
        reasons.append('Learner feedback is mixed into the source options; recover the original choices and key')
    prompt,opts,seq=option_parts(before) if rawtype in ['MCQ','MSQ','MULTI-SELECT'] or subject.startswith('English') else (before,[],[])
    inline_line=next((i for i,l in enumerate(before) if re.match(r'^Ans\s*:',l['text'],re.I)),None)
    if inline_line is not None:
        inline_text=before[inline_line]['text']
        found=re.findall(r'\b([a-z])\b',re.sub(r'^Ans\s*:\s*','',inline_text,flags=re.I),re.I)
        if found:ans=', '.join(found).upper()
        explanation=[{**l,'text':re.sub(r'^Reason\s*:\s*','',l['text'],flags=re.I)} for l in before[inline_line+1:]]+explanation
        before=before[:inline_line]
        prompt,opts,seq=option_parts(before)
    if sum(bool(ANSWER.match(l['text'].strip())) for l in lines)>1:
        reasons.append('Multiple source answer lines: check for merged question fragments')
    # Several English PDFs accidentally placed the question into option A.
    if not joined(prompt) and len(opts)>=3 and subject.startswith('English'):
        prompt,opts=opts[0],opts[1:];seq=seq[1:];notes.append('Restored stem from spurious first option; shifted source answer index')
        shift=1
    else:shift=0
    original=joined(before)
    if re.search(r'hall ticket|attendance|final submission|will not be graded|^Tab\s+\d+$',original,re.I):
        return None,refs,['Administrative content, not a question']
    embedded=list(INLINE_KEY.finditer(original))
    embedded_keys=[]
    for m in embedded:
        token=m[1] or m[2];embedded_keys+=re.findall(r'\b([a-z])\b',token,re.I)
    for l in prompt:
        value=INLINE_KEY.sub('',l['text'])
        l['text']=value.rstrip() if l.get('code') else value.strip()
    # Some English solutions and original answer keys were appended to the last option.
    for opt in opts:
        for l in opt:
            m=INLINE_KEY.search(l['text'])
            if m:
                text=l['text'];tail=text[m.end():].strip(' .-')
                if tail:explanation.append({**l,'text':tail})
                l['text']=text[:m.start()].rstrip()
    marks=re.search(r'(\d+(?:\.\d+)?)\s*marks?',headtail,re.I) or re.search(r'\((\d+(?:\.\d+)?)\s*marks?\)',original,re.I)
    diff=re.search(r'\b(easy|medium|hard)\b',headtail,re.I)
    q={'type':'','prompt':blocks(prompt,subject),'marks':float(marks[1]) if marks else 1,'difficulty':diff[1].lower() if diff else 'medium'}
    if q['marks'].is_integer():q['marks']=int(q['marks'])
    if explanation:q['explanation']=blocks(explanation,subject)
    if not q['prompt'] or len(joined(prompt))<8:reasons.append('Missing or incomplete question stem')
    if opts:
        keys=[ord(x.upper())-65-shift for x in re.findall(r'\b([A-Z])\b',ans,re.I)]
        if re.fullmatch(r'True|False',ans,re.I):
            keys=[i for i,opt in enumerate(opts) if joined(opt).strip().lower()==ans.lower()]
        if embedded_keys:
            original_keys=sorted(set(ord(x.upper())-65-shift for x in embedded_keys))
            if original_keys!=sorted(keys):notes.append(f'Used embedded original answer key {embedded_keys} in place of booklet label {ans}')
            keys=original_keys
        keys=sorted(set(keys))
        if not keys or any(k<0 or k>=len(opts) for k in keys):reasons.append(f'Missing or invalid MCQ key: {ans!r}')
        q['type']='mcq_multi' if rawtype in ['MSQ','MULTI-SELECT'] or len(keys)>1 else 'mcq_single'
        q['options']=[blocks(opt,subject) for opt in opts]
        if any(not opt or not ''.join(b['value'] for b in opt).strip() for opt in q['options']):reasons.append('An option is empty in the source')
        normalized_options=[' '.join(' '.join(b['value'] for b in opt).split()) for opt in q['options']]
        if len(set(normalized_options))!=len(normalized_options):reasons.append('Duplicate option content: check source for missing formulas or fragments')
        if q['type']=='mcq_multi':q['correct_answers']=keys
        elif keys:q['correct_answer']=keys[0]
    elif rawtype in ['MCQ','MSQ','MULTI-SELECT']:reasons.append('Cannot recover a complete option list')
    elif re.fullmatch(r'(True|False)[).\s]*',ans,re.I):
        q.update(type='mcq_single',options=[[block('True')],[block('False')]],correct_answer=0 if ans.lower().startswith('true') else 1)
    elif re.fullmatch(r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?',ans):
        q.update(type='numerical',numerical_answer=float(ans),numerical_tolerance=.01)
    else:
        # Preserve symbolic answers as strings; never strip symbols to manufacture a number.
        if not ans:reasons.append('Source answer is blank')
        if re.fullmatch(r'\(?[a-d]\)?',ans,re.I):reasons.append('Source uses an option-letter key but the options are missing')
        q.update(type='short_answer',acceptable_answers=[ans] if ans else [])
    stem=joined(prompt)
    if re.search(r'\b(?:above|previous question|previously|shown earlier)\b',stem,re.I) and not any(l.get('code') for l in prompt):
        reasons.append('Reference to earlier content needs its exact context attached')
    if re.search(r'\b(?:a\)|b\)|c\)|d\))\s*\w',stem,re.I) and not opts:
        reasons.append('Embedded options need restructuring')
    if re.search(r'\b(?:audio|listen|hear at|CLICK HERE)\b',stem,re.I):
        if not re.search(r'https?://\S+',stem):reasons.append('Listening question lacks an attached playable audio source/transcript')
        elif re.search(r'hear at|listen|stressed syllable',stem,re.I):reasons.append('External audio dependency needs verification or transcript')
    if re.search(r'\b(?:figure|graph|diagram|table|matrix)\s*(?:given\s*)?(?:below|above|shown|following)|\b(?:below|above)\s+(?:figure|graph|diagram|table|matrix)',stem,re.I):
        reasons.append('Referenced visual needs comparison with the PDF')
    if re.search(r'\b(?:underlined|highlighted|boldfaced)\b',stem,re.I):reasons.append('Required emphasis must be recovered from the page')
    if re.search(r'(?:\bis|\bbe|\bthe|\bof|\bas|\band|\ba|\bfind|\blet)\s*$',stem,re.I):reasons.append('Question appears truncated in source')
    if subject=='Mathematics 1':reasons.append('Mathematical layout must be recovered from the page')
    refs['notes']=notes
    return q,refs,reasons

def balanced_sizes(n):
    assert n>=5
    parts=math.ceil(n/10);base,extra=divmod(n,parts)
    sizes=[base+(i<extra) for i in range(parts)]
    assert min(sizes)>=5 and max(sizes)<=10 and sum(sizes)==n
    return sizes

def validate(paper):
    assert paper['schema_version']=='1.1' and 5<=len(paper['questions'])<=10
    assert paper['section'] in ['quiz1','quiz2','endterm','practice','practice_graded','mock_test']
    def valid_block(b):
        assert b['kind'] in ['text','code','image']
        if b['kind']=='image':
            url=b.get('url',b.get('asset',''))
            assert url.startswith('/assets/exam-examples/question-crops/') and '..' not in url and (PROJECT/url.lstrip('/')).is_file(),url
            assert b.get('alt','').strip()
        else:
            assert b['value'].strip()
            if b['kind']=='code':assert b['language'] in ['python','pseudocode','text']
        return True
    for q in paper['questions']:
        assert q['marks']>0 and q['difficulty'] in ['easy','medium','hard'] and q['prompt']
        for field in ['prompt','explanation']:
            for b in q.get(field,[]):
                valid_block(b)
        if q['type'].startswith('mcq_'):
            assert len(q['options'])>=2 and all(opt and all(valid_block(b) for b in opt) for opt in q['options'])
            keys=q['correct_answers'] if q['type']=='mcq_multi' else [q['correct_answer']]
            assert keys and len(set(keys))==len(keys) and all(type(i)==int and 0<=i<len(q['options']) for i in keys)
        elif q['type']=='numerical':assert math.isfinite(q['numerical_answer']) and q['numerical_tolerance']>=0
        elif q['type']=='short_answer':assert q['acceptable_answers'] and all(a.strip() for a in q['acceptable_answers'])
        else:raise AssertionError(q['type'])

def main():
    inventory=json.loads((ROOT/'source-inventory.json').read_text());reports=[];candidates=[]
    for entry in inventory:
        data=json.loads((ROOT/'cache'/(entry['key']+'.json')).read_text());subject,section,title=source_metadata(data['source']);lines=normalize_headers(load_lines(data))
        chunks=[];current=[];context=[];collecting_context=False;current_context=[];context_header=''
        for line in lines:
            if re.search(r'^(?:📖\s*|[A-Z]\s+)?(?:Passage\s*/\s*Context|Comprehension)\b',line['text'].strip(),re.I):
                if current:chunks.append((current,current_context));current=[]
                context=[];collecting_context=True;context_header=line['text']
            elif HEADER.match(line['text'].strip()):
                if current:chunks.append((current,current_context))
                current=[line];current_context=list(context);collecting_context=False
                numbers=context_scope(context_header+' '+joined(context))
                qnum=int(HEADER.match(line['text'].strip())[1])
                if numbers and qnum not in numbers:current_context=[]
            elif collecting_context:
                if not NOISE.match(line['text'].strip()) and line['text'].strip():context.append(line)
            elif current:current.append(line)
        if current:chunks.append((current,current_context))
        accepted=[];rejected=[]
        for chunk,shared in chunks:
            q,ref,reasons=parse_question(chunk,subject)
            if q and shared:
                q['prompt']=blocks(shared,subject)+q['prompt']
                ref['notes'].append('Attached the exact shared passage from the source')
                ref['pages']=sorted(set(ref['pages']+[l['page'] for l in shared]))
                reasons=[reason for reason in reasons if reason!='Reference to earlier content needs its exact context attached']
            row={'source':data['source'],'source_key':data['key'],'subject':subject,'section':section,'quiz_title':title,**ref,'question':q,'issues':reasons,'raw_source':joined(chunk)}
            candidates.append(row)
            (rejected if reasons else accepted).append(row)
        if not chunks:rejected.append({'issues':['Original solution-booklet layout requires page-based extraction'],'pages':list(range(2,len(data['pages'])+1))})
        reports.append({'source':data['source'],'source_key':data['key'],'subject':subject,'section':section,'quiz_title':title,'detected_question_headers':len(chunks),'accepted_candidates':len(accepted),'review_required':len(rejected)})
    (ROOT/'candidates.json').write_text(json.dumps(candidates,ensure_ascii=False,indent=2))
    (ROOT/'extraction-progress.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2))
    print('CANDIDATES',len(candidates),'WITHOUT_FLAGS',sum(not c['issues'] for c in candidates),'REVIEW',sum(bool(c['issues']) for c in candidates))
    print(collections.Counter(issue for c in candidates for issue in c['issues']))

if __name__=='__main__':
    for n in range(5,201):balanced_sizes(n)
    assert balanced_sizes(11)==[6,5] and balanced_sizes(14)==[7,7] and balanced_sizes(21)==[7,7,7]
    assert context_scope('Q5 and Q10')=={5,10} and context_scope('Q1-Q3')=={1,2,3}
    assert option_parts([{'text':'Prompt'},{'text':'✓one'},{'text':'B two'}])[1]
    sample=[{'text':'Q1 MCQ 1 mark','page':1},{'text':'What is printed?','page':1},{'text':'for i in range(2):','code':True,'page':1},{'text':'    print(i)','code':True,'page':1},{'text':'A 0, 1','page':1},{'text':'B 1, 2','page':1},{'text':'Answer: A','page':1}]
    assert parse_question(sample,'Python')[0]['prompt'][1]['value']=='for i in range(2):\n    print(i)'
    main()
