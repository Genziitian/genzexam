"""Recover original Python questions; keep every editorial repair and exclusion auditable."""
from pathlib import Path
import json,re,copy,ast,collections,math
from extract_batch import ROOT,PROJECT,validate,balanced_sizes
rows=[copy.deepcopy(r) for r in json.loads((ROOT/'candidates.json').read_text()) if r['subject']=='Python']
lookup={(r['section'],int(re.search(r'Week (\d+)',r['quiz_title'])[1]),r['question_number']):r for r in rows}
def row(w,n,pa=False):return lookup['practice' if pa else 'practice_graded',w,n]
def q(w,n,pa=False):return row(w,n,pa)['question']
def txt(s):return {'kind':'text','value':s}
def code(s,lang='python'):return {'kind':'code','language':lang,'value':s.strip()}
def note(r,s):r.setdefault('recovery_notes',[]).append(s)
def explain(r,s):r['question']['explanation']=[txt(s)]
def skip(w,nums,reason,pa=False):
 for n in nums:row(w,n,pa)['excluded_reason']=reason

def choice(r,options,keys,multi=True,stem=None,code_options=True):
 t=r['question'];t['type']='mcq_multi' if multi else 'mcq_single'
 for field in ['acceptable_answers','numerical_answer','numerical_tolerance','correct_answer','correct_answers']:t.pop(field,None)
 t['options']=[[code(s) if code_options else txt(s)] for s in options]
 t['correct_answers' if multi else 'correct_answer']=keys if multi else keys[0]
 if stem is not None:t['prompt']=stem
 note(r,'Recovered the original embedded option boundaries and corrected the answer using Python semantics.')

def setkey(r,keys,multi=None,why=''):
 t=r['question'];old={k:t[k] for k in ['type','correct_answer','correct_answers'] if k in t}
 if multi is None:multi=t['type']=='mcq_multi'
 t['type']='mcq_multi' if multi else 'mcq_single';t.pop('correct_answer',None);t.pop('correct_answers',None)
 t['correct_answers' if multi else 'correct_answer']=keys if multi else keys[0]
 if old!={k:t[k] for k in old if k in t}:note(r,'Source key/type corrected: '+why)
 if why:explain(r,why)

def text_prompt(r,s):r['question']['prompt']=[txt(s)]
def replace_code(r,s,index=0):
 bs=[b for b in r['question']['prompt'] if b['kind']=='code'];bs[index]['value']=s

def cb(r):return '\n'.join(b['value'] for b in r['question']['prompt'] if b['kind']=='code')
def intro(r):return [b for b in r['question']['prompt'] if b['kind']=='text']
def parts(s,marker):
 hits=list(re.finditer(r'(?m)^ {0,2}(?='+marker+r')',s));assert len(hits)>=2,(marker,s[:90])
 return [s[h.start():hits[i+1].start() if i+1<len(hits) else len(s)].strip() for i,h in enumerate(hits)]
def indents(s):
 try:ast.parse(s);return s
 except SyntaxError:pass
 # Native PDF placement varies by up to one monospaced glyph; align to the source's indentation levels.
 out='\n'.join(' '*(4*round((len(l)-len(l.lstrip()))/4))+l.lstrip() for l in s.splitlines())
 try:ast.parse(out);return out
 except SyntaxError:return s

# Week 1: precedence questions embed four unlabelled choices in a code panel.
for n,keys in [(14,[1]),(15,[0,2]),(16,[0]),(17,[2]),(18,[2]),(19,[2])]:
 r=row(1,n);lines=cb(r).splitlines();assert len(lines)==5
 choice(r,lines[1:],keys,n!=19,intro(r)+[code(lines[0])])
 if n==19:explain(r,'Exponentiation has higher precedence than multiplication, which has higher precedence than addition: (8.2 * (10 ** 4)) + 19.')
setkey(row(1,20),[1,2],why='print is a built-in function. Its default separator between arguments is a space and its default ending is a newline. A REPL displays a string representation with quotes, whereas print displays the string contents.')
setkey(row(1,21),[2,3],why='input is a built-in function, not a keyword. It reads one line and returns a string. It accepts at most one positional prompt argument.')
skip(1,range(22,27),'The source refers to Python Tutor code but contains neither the code nor a usable Tutor URL; line-specific answers cannot be verified.')
r=row(1,28);t=r['question'];t['prompt']=[txt('E_1 and E_2 are Boolean variables. Consider the following code. Which scenarios are possible when the code executes? Treat each scenario independently.'),code('E_1 and E_2 and 1 / 0\nprint(E_2)')];t['options']=t['options'][1:];setkey(r,[0,1,2],why='If both variables are True, division by zero raises an exception. Otherwise the expression short-circuits and print(E_2) can print True or False.')
replace_code(row(1,27),cb(row(1,27)).replace('\n ','\n'));explain(row(1,27),'De Morgan’s law gives not (expr_1 or expr_2) == ((not expr_1) and (not expr_2)) for all four Boolean input pairs, so the comparison always prints True.')
r=row(1,6,True);s=cb(r);r['question']['prompt']=intro(r)+[code(s[:s.index('\n10\n')]),txt('Input (one integer per line):'),code('10\n11\n12','text')];explain(r,'The sum is 33. Python division by 3 produces the float 11.0.')
q(1,3,True)['prompt'][-1]['language']='text'

# Week 2: attach the exact shared aliasing example and repair demonstrable format keys.
r=row(2,4);r['question']['prompt'].insert(0,copy.deepcopy(q(2,1)['prompt'][-1]));note(r,'Attached the exact shared aliasing program from source Q1–Q3.')
setkey(row(2,8),[3,4,6],why='str(0.5) + "00", f"{0.5}00", and f"{0.545:.1f}00" each give "0.500". Width-only :03 formatting does not add trailing fractional zeros.')
skip(2,[9],'All options include a rupee symbol absent from the required output; no option matches the source stem exactly.')
skip(2,[17],'The unspecified string can be long enough for s[3] or too short; the source error key cannot be determined from the given information.')
skip(2,[23,24,25],'Original PDF already merges possible output choices into one code panel and loses their boundaries; no complete recoverable option list.')
skip(2,[6],'Source multiline-string options and answer are merged/truncated; exact whitespace-sensitive option boundaries are not recoverable.')
r=row(2,15);r['question']['prompt'].insert(0,txt('Assume that "3" is present in s.'));note(r,'Made the successful-index lookup precondition explicit; otherwise the source type question is ambiguous.')
r=row(2,16);r['question']['prompt'].insert(0,txt('Assume s is non-empty.'));note(r,'Made the indexing precondition explicit.')
r=row(2,18);r['question']['prompt']=intro(r)+[code('x = bool(input())'),txt('Input: False')];explain(r,'input returns the non-empty string "False". Every non-empty string has Boolean value True.');note(r,'Separated the explicit source input and removed merged answer alternatives from the program.')
r=row(2,26);s=cb(r);source=s[:s.index('\n  if a or b:')];opts=["if a or b:\n    print('ab')\nelif c:\n    print('c')","if not (not a or not b):\n    print('ab')\nelif c:\n    print('c')","if a:\n    if b:\n        print('ab')\nif c:\n    print('c')","if a and b:\n    print('ab')\nelif c:\n    print('c')","if a and b:\n    print('ab')\nif c:\n    print('ac')","if a and b:\n    print('ab')\nif c:\n    if not(a and b):\n        print('c')","if a and b:\n    print('ab')\nif c:\n    if not a:\n        print('c')","if a and b:\n    print('ab')\nif not a and c:\n    print('c')"]
choice(r,opts,[6,7],stem=intro(r)+[code(source)]);explain(r,'The original prints ab only when a and b are True, and prints c only when a is False and c is True. Only options 7 and 8 preserve both conditions for all Boolean inputs.')
r=row(2,27);choice(r,[l.strip() for l in cb(r).splitlines()],[3],stem=intro(r));explain(r,'The valid syntax is from math import pi as math_pi. The other listed import forms are syntax errors.')
for n,marker,keys in [(28,'sentence =',[1]),(30,'num =',[2])]:
 r=row(2,n);choice(r,parts(cb(r),marker),keys,False,intro(r))
r=row(2,30);r['question']['prompt']=[txt('A three-digit number is a sandwich number if the sum of its first and last digits equals its middle digit. Select the program that reads such a number and prints "sandwich" when this condition holds, and "plain" otherwise. Examples: 143 → sandwich; 118 → plain.')]
r=row(2,29);s=cb(r);program=s[:s.index('\n1234')];choice(r,['1234\n1234\n1234\n1234','1\n2\n3\n4','1\n1\n1\n1','4\n4\n4\n4'],[1],False,intro(r)+[code(program),txt('Input: 1234')]);explain(r,'Unpacking the four-character input assigns "1", "2", "3", "4" to a, b, c, d; each print writes its character on a separate line.')
r=row(2,31);s=cb(r);program=s[:s.index('\n  tacit')];choice(r,['tacit','trumpet','ease','TrumpeT','TaciT'],[0,1,2],stem=[txt('A word is valid when the following program prints True for that word as input. Select all valid words.'),code(program)],code_options=False)
skip(2,[32],'Source drops the Boolean connector between conditions and duplicates fragments of multiple options; cannot recover exact alternatives.')
setkey(row(2,1,True),[0,1,4],True,'a_, _a, and a_variable are valid identifiers. An identifier cannot begin with a digit or contain spaces.')
r=row(2,6,True);s=cb(r);r['question']['prompt']=intro(r)+[txt('Block 1:'),code(s[:s.index("\nif E:\n   print('good')\nprint('bad')")]),txt('Block 2:'),code("if E:\n    print('good')\nprint('bad')"),txt('Block 3:'),code("print('good')\nprint('bad')")];setkey(r,[3,4],why='When E is False, blocks 1 and 2 print only bad. When E is True, blocks 2 and 3 print good followed by bad. No two blocks are equivalent for both Boolean values.')
setkey(row(2,7,True),[0,2],why='If bool_var starts True, x is incremented and then decremented after the flag becomes False; otherwise x is unchanged. Thus the final x is independent of the initial flag and line 5 is never executed.')
skip(2,[8],'The question refers to missing code involving three Boolean variables; only a result table remains in its explanation.',True)
skip(2,[12],'The rendered input is only "1", yet the four-variable unpacking choices contain no ValueError answer; source stem/options conflict.',True)

# Week 3: separate exact program/output panels and retain only complete option sets.
for n,marker,opts,keys in [(2,'\nAlbus Percival', ['Albus','Dumbledore','AP','APBWD'],[3]),(3,'\n  12345',['12345','|||||','|1|2|3|4|5','1|2|3|4|5|','|1|2|3|4|5|'],[4]),(9,'\n  abet',['abet','enamel','eatery','onetime'],[0,1,3])]:
 r=row(3,n);s=cb(r);program=s[:s.index(marker)];stem=intro(r)+[code(program)]
 if n==2:stem.append(txt('Input: Albus Percival Brian Wulfric Dumbledore'))
 choice(r,opts,keys,n==9,stem,False)
 if n==3:
  for o in r['question']['options']:o[0]['kind']='code';o[0]['language']='text'
r=row(3,5);s=cb(r);opts=['print(country_code, currency_code, exchange_rate, sep = ", ")','print(f"{country_code}, {currency_code}, {exchange_rate:2.2f}")','print("{}, {}, {:2.2f}".format(country_code, currency_code, exchange_rate))','print("{0}, {1}, {2:2.2f}".format(country_code, currency_code, exchange_rate))','print("{a}, {b}, {c:2.2f}".format(a = country_code, b = currency_code, c = exchange_rate))','print("%s, %s, %2.2f"%(country_code, currency_code, exchange_rate))'];choice(r,opts,[1,2,3,4,5],stem=[txt('Given country_code = "IN", currency_code = "RS", exchange_rate = 73.2272, select all statements that print exactly the following record:'),code('IN, RS, 73.23','text')]);explain(r,'All five formatted alternatives round the exchange rate to two decimal places. The unformatted print retains 73.2272.')
r=row(3,6);t=r['question'];t['prompt'][0]['value']+=' Hello Python! in Python?';t['prompt'][-1]['language']='text';t['options']=t['options'][1:];setkey(r,[0],False,'String repetition can generate the output: print("Hello Python!\\n" * 10, end="").')
skip(3,[8],'Source prints placeholder format strings such as %-ns; all options are invalid and two alternatives are identical.')
skip(3,[11],'Several whitespace-sensitive while-loop options are intrinsically malformed/duplicated in the source; the complete intended choices cannot be recovered.')
r=row(3,10);r['question']['prompt'].insert(0,copy.deepcopy(q(3,9)['prompt'][1]));t=r['question'];t['options'][3][0]['value']+=' '+t['options'][4][0]['value'];t['options'].pop(4);note(r,'Attached exact shared validation code and rejoined a wrapped final option.')
r=row(3,12);choice(r,parts(cb(r),'result ='),[0,1,2,4],stem=intro(r));explain(r,'The correct alternatives sum 1 + 3 + … + (2n−1), which is n². Option 3 includes the missing first term separately; option 5 generates the same odd numbers using negative indices.')
r=row(3,16);replace_code(r,cb(r).replace('for word in words.split():','for word in sentence.split():'));note(r,'Corrected source variable typo words → sentence; sentence is the actual input variable.')
skip(3,[1,5,6],'The original PDF has fragmented options with missing numeric terms; crops contain the same missing information.',True)
r=row(3,2,True);setkey(r,[2],False,'The loop prints i exactly when i divides n, so the printed values are the factors of n.')
r=row(3,7,True);s=cb(r);t=r['question'];t['prompt']=[txt('How many asterisks (*) does the following code print?'),code(s)];t['type']='numerical';t.pop('acceptable_answers',None);t['numerical_answer']=4950;t['numerical_tolerance']=0;explain(r,'The iteration with index i prints i asterisks for i = 0,…,99. Their sum is 99×100/2 = 4950.')
skip(3,[8],'No code containing the referenced break statement is present in the source.',True)
setkey(row(3,9,True),[1,2],True,'Formatting with .2f always prints two digits after the decimal point. Both 1.29 and 1234.20 are possible; 1.2 is not.')

# Week 4: recover code alternatives, shared mean test, and correct source answer keys.
skip(4,[1,2],'The dice-roll generation/counting program referenced by these questions is missing from the booklet.')
r=row(4,3);s=cb(r).replace('      break','       break');replace_code(r,s);setkey(r,[0,3],why='flag becomes True only when y belongs to L and y × len(L) equals the sum of L; hence y is the arithmetic mean.')
r=row(4,4);r['question']['prompt']=[txt('Let L contain the first n positive integers, with n > 0. Under what condition will flag be True after the following code?'),copy.deepcopy(q(4,3)['prompt'][-1])];note(r,'Attached the exact shared mean-test program.')
r=row(4,5);s=cb(r);program=s[:s.index('\n  [90,')].replace('          break','           break');choice(r,['[90, 47, 8, 18, 10, 7]','[7, 10, 18, 8, 47, 90]','[7, 8, 10, 18, 47, 90]','[90, 47, 18, 10, 8, 7]','[90, 7, 8, 10, 18 47]'],[2],False,intro(r)+[code(program)])
for n,marker,keys in [(6,'points =',[3]),(7,'L =',[0,2]),(8,'triplets =',[0,1,2]),(9,'P =',[1,2]),(12,'def unique',[0,2]),(13,'def poly\\(',[2]),(14,'def poly_zeros',[3])]:
 r=row(4,n);ps=parts(cb(r),marker);stem=intro(r)
 if n==7:stem=stem+[code(ps.pop(0))]
 choice(r,ps,keys,n not in [13,14],stem)
r=row(4,6);r['question']['prompt']=[txt('The grid contains integer points (x, y) with 0 ≤ x ≤ 4 and 0 ≤ y ≤ 4. Create a list named points whose elements are coordinate tuples (x, y). Select all correct programs.')]
r=row(4,8);r['question']['prompt']=[txt('Select all programs that store in triplets every integer tuple (x, y, z) satisfying x² + y² = z² and 0 < x < y < z < 100.')]
r=row(4,9);r['question']['prompt']=[txt('L is a list of non-empty names. Select all programs that create a list P of precisely those names in L whose first letter is an uppercase English letter.')];note(r,'Made the indexing precondition explicit.')
r=row(4,10);s=cb(r);ps=parts(s,r'(?:P =|L = \[word|print\(\[word)');choice(r,ps,[0,1,2],stem=intro(r))
r=row(4,11);setkey(r,[0],False,'For equal real arguments, a <= b is True, so the first return executes. Returning immediately exits the function.');r['question']['prompt'][0]['value']='For a real number x, which return statement executes when minmax(x, x) is called?'
r=row(4,12);r['question']['prompt'][0]['value']=r['question']['prompt'][0]['value'].split('A few instances')[0].strip();note(r,'Removed a missing sample-table reference; the full behavioral specification remains.')
r=row(4,13);r['question']['prompt']=[txt('L = [a_0, a_1, …, a_n] is a list of polynomial coefficients. Select the function poly(L, x_0) that returns a_0 + a_1*x_0 + … + a_n*x_0**n. For example, poly([1, 2, 3], 5) returns 86.')]
r=row(4,14);r['question']['prompt']=[txt('The helper poly(L, x) evaluates the polynomial with coefficient list L at x: a_0 + a_1*x + … + a_n*x**n. Select the function poly_zeros(L, a, b) that returns all integer zeros in the inclusive interval [a, b], once each and in increasing order. For example, poly_zeros([2, -3, 1], 0, 4) returns [1, 2].')];note(r,'Attached the exact polynomial evaluation contract instead of an orphan reference to an earlier question.')
setkey(row(4,4,True),[0,3],why='Both correct alternatives test the parity of each element and append the element itself in the original order.')
for w,n in [(4,5),(5,16)]:
 r=row(w,n,True);s=cb(r);replace_code(r,s.removesuffix('\nP'));r['question']['options'][0][0]['value']='P '+r['question']['options'][0][0]['value'];setkey(r,[1,2],why='Negating, sorting ascending, and negating again gives the elements of P sorted in descending order. The multiset is preserved, but P need not originally have that order.')
skip(4,[11],'This source item is an ungraded subjective information-usefulness survey rather than a knowledge question.',True)
setkey(row(4,16,True),[0,1,3],why='The filtered comprehension, nested loops with the same test, and (x, 100−x) for x = 1,…,99 all produce exactly the required positive ordered pairs.')
setkey(row(4,17,True),[1,2],why='Both correct alternatives enforce x+y == 100 and x <= y. The other alternatives omit a required condition.')
setkey(row(4,19,True),[0,1],why='The loop and the ternary list comprehension both put 1 at even indices and 0 at odd indices. The third alternative has invalid comprehension syntax.')
r=row(4,24,True);r['question']['prompt']=[txt('The Euclidean distance of (x, y) from the origin is sqrt(x²+y²), and the Manhattan distance is |x|+|y|. Select the function distance(x, y, metric) that returns the requested distance and defaults to metric="manhattan" when it is omitted. abs returns an absolute value.')];note(r,'Restored the dropped square root and absolute-value notation from the source code and solution.')
r=row(4,26,True);t=r['question'];t['options'][2][0]['value']+=' '+t['options'][3][0]['value'];t['options'].pop();setkey(r,[2],False,'The first line calls add before its definition has executed, so Python raises NameError.');t['prompt'].insert(0,txt('Assume this is a standalone program and add has not already been defined.'))
skip(4,[28,29],'The welcome function definition is absent from the source booklet.',True)

# Week 5: preserve exact list-generation/frequency definitions inside each dependent item.
skip(5,[1,2],'The some_function definition required by the question is absent from the source booklet.')
skip(5,[3],'The source overlaps a matrix-comparison option with its footer, destroying part of a whitespace-sensitive code alternative.')
skip(5,[10],'The color assignment diagram defining the intended output is missing from the source; four mappings remain without a specification.')
skip(5,[11],'The source overlaps a symmetric-matrix code alternative with a page footer and loses its assignments/indentation.')
for n,marker,keys in [(4,'import random',[0]),(5,'P =',[1,3]),(8,'def most_freq',[3]),(9,'def streak',[2])]:
 r=row(5,n);s=cb(r)
 if n in [4,5]:s=s[s.index('\n  ')+1:]
 choice(r,parts(s,marker),keys,n==5,intro(r))
context='nums is a list of 10,000 integers, each between 1 and 10 inclusive. P is a dictionary with keys 1,…,10, where P[k] is the frequency of k in nums, including zero frequencies.'
for n in range(5,10):
 r=row(5,n);r['question']['prompt'].insert(0,txt(context));note(r,'Attached the exact generated-list and frequency-table context from the source questions.')
r=row(5,6);t=r['question'];t['options']=[[txt('It is True if and only if nums is sorted in ascending order.')],[txt('It is True if and only if nums is sorted in descending order.')],[txt('It is always True and does not depend on the order of elements in nums.')],[txt('It is always False and does not depend on the order of elements in nums.')]];setkey(r,[2],False,'The sum of all frequencies in P equals the length of nums, irrespective of the order of its elements.')
r=row(5,7);choice(r,[l.strip() for l in cb(r).splitlines()],[1],False,intro(r));explain(r,'P[5] counts the occurrences of 5 among 10,000 equally likely list positions, so the probability is P[5]/10000.')
skip(5,[4],'This source item is a subjective usefulness survey rather than a knowledge question.',True)
setkey(row(5,6,True),[0,1],why='The correct implementations assign len(word) directly. Reading D[word] before initializing that key raises KeyError in the other alternatives.')
skip(5,[7],'Original source fragments code loops into separate options and drops the constant after letters.index(letter)+; the full intended list of snippets cannot be recovered.',True)
r=row(5,11,True);replace_code(r,cb(r).removeprefix('(batsman, opposition, runs)\n'));setkey(r,[0,2],why='Laxman scores 289+30 = 319 against AUS. Dravid scores 210+210+50 = 470 against WI. These are the only listed player/opposition totals of at least 300.')
skip(5,[13],'Two dimension options are rendered blank in the source, so their alternatives cannot be recovered.',True)
setkey(row(5,14,True),[1,3],why='Take the last element of each row, either directly with matrix[i][-1] or by testing j == n−1 in nested loops.')
setkey(row(5,15,True),[0,2,3],why='Each successful iteration removes one x. With 10 iterations and no exception, the original list consists of ten copies of x and the final list is empty.')
setkey(row(5,17,True),[0,3],why='The first and fourth alternatives accumulate row i into rsum[i]. The second discards previous rows, and the third accumulates column sums.');q(5,17,True)['prompt'].insert(0,txt('Assume M is a non-empty square matrix.'));note(row(5,17,True),'Made the square-matrix condition required by every source option explicit.')

# Week 6 collection-operation type questions.
for n in [1,11,13]:q(6,n)['prompt'].insert(0,txt('Assume the elements are mutually comparable wherever sorting is required.'))
q(6,7)['prompt']=[txt('l is a list of strings. What types can be returned by the expression below as l varies?'),code("l.index('hi') if 'hi' in l else None")];note(row(6,7),'Clarified that the question asks the possible return types across different lists.')
q(6,19)['prompt']=[txt('s is a set of 10 integers. What is the output type of s.pop(4), or does this expression raise an error?')];note(row(6,19),'Removed duplicated stem fragments.')
for n in [24,25,26,27]:q(6,n)['prompt'].insert(0,txt('Use Python 3.9 or later, which supports dictionary union with |.'))

# Week 7: clear single-token source typos, keeping the original algorithms.
for n,old,new in [(6,"word*2 for word in words if","word*2 for word in sentence.split() if"),(10,'len(str(num)<2)','len(str(num))<2'),(14,'min(num)','min(nums)'),(15,'len(str(abs(x)))','len(str(abs(x))))')]:
 r=row(7,n);s=cb(r);assert old in s,(n,old);replace_code(r,s.replace(old,new));note(r,'Corrected an unambiguous source variable/parenthesis typo: '+old+' → '+new)
q(7,6)['prompt'][-1]['value']=cb(row(7,6)).replace('word*2 for word in words if','word*2 for word in sentence.split() if')
setkey(row(7,4),[0,1],True,'The condition filters words containing a, and next reduces the matching sequence to its first element (or None).')
setkey(row(7,5),[0,1,2],True,'The generator filters words containing a and maps each to word*2; next reduces that sequence to its first result.')
for n in [14,15]:q(7,n)['prompt'].insert(0,txt('Assume nums is a non-empty list of integers.'))

# Week 8: keep the full original CSV and the exact helper required by each question.
r=row(8,1);s=cb(r);csv,program=s.split('\n def do_something',1);csv='\n'.join(l.strip() for l in csv.splitlines());program='def do_something'+program
r['question']['prompt']=intro(r)+[txt('Contents of scores.csv:'),code(csv,'text'),code(program)]
get_s=cb(row(8,2));get_s=get_s[:get_s.index('\nSeqNo,')]
for n in [2,3,4]:
 r=row(8,n);s=cb(r)
 if n==2:program=get_s
 elif n==3:program=s[:s.index('\nSeqNo,')]
 else:program=s[:s.index('\n   SeqNo,')]
 r['question']['prompt']=intro(r)+[txt('Contents of scores.csv (final line has no trailing newline):'),code(csv,'text')]+([code(get_s)] if n==3 else [])+[code(program)]
 note(r,'Separated the complete CSV, dependent helper, and current program; removed unrelated copied helper code.')
r=row(8,4);t=r['question'];t['type']='short_answer';out='SeqNo,Name,CT,Python,PDSA\n1,Sahana,90,80,70\n3,Suchitra,100,100,100\n5,Aisha,85,95,90\n7,Soundarya,85,75,65\n9,Brinda,65,95,85';t['acceptable_answers']=[out];t['prompt'][0]['value']='What are the complete contents of out.csv after the following program executes?';note(r,'Retained the original file-writing task as a short answer because the source merges all file-content alternatives.')
skip(8,[5],'The source file-writing options have missing loop-body indentation, including the claimed correct option; exact executable alternatives cannot be recovered.')

# Week 9: restore f/g directly from source worked solutions, and h from the factorial definition/call.
recursion="def f(n):\n    if n < 10:\n        return 1\n    return 1 + f(n // 10)\n\ndef g(n):\n    if n < 10:\n        return n\n    return n % 10 + g(n // 10)\n\ndef h(n):\n    if n <= 1:\n        return n\n    return n * h(n - 1)"
for n in range(1,5):replace_code(row(9,n),recursion);note(row(9,n),'Recovered truncated recursion lines from the exact f/g source explanations; h is the factorial recurrence stated in the source.')
setkey(row(9,1),[1],False,'Each recursive call removes one decimal digit and adds one, so f counts the digits of a positive integer.')
setkey(row(9,2),[0],False,'The remainder n % 10 is the final digit, and g recursively sums all earlier digits.')
setkey(row(9,3),[2],False,'h(100) returns 100!, and g then sums its decimal digits.')
setkey(row(9,4),[1],False,'h(100) returns 100!, and f then counts its decimal digits.')
for n,keys in [(5,[1,5]),(6,[2,3]),(7,[0])]:
 r=row(9,n);marker='def bin_to_dec' if n==7 else 'def equality';choice(r,parts(cb(r),marker),keys,n!=7,intro(r));
 if n in [5,6]:r['question']['prompt'].insert(0,txt('equality(P, Q) must return True exactly when the two input lists have equal lengths and equal elements at every corresponding index, including empty lists.'))
r=row(9,7);r['question']['prompt']=[txt('A binary number is a non-empty string containing only 0 and 1. Select bin_to_dec(bin) that returns its decimal value as an integer. For bits a_1…a_n the value is a_1*2**(n−1) + … + a_n*2**0. For example, "1011" represents 11.')]
for n,tail,target in [(1,'word','word'),(2,'some_list','some_list')]:
 r=row(9,n,True);s=cb(r);replace_code(r,s.removesuffix('\n'+tail));r['question']['prompt'][0]['value']=r['question']['prompt'][0]['value'].replace('\nis a ', '\n'+target+' is a ');note(r,'Restored the variable name displaced to the end of the code panel.')
skip(9,[3],'The member function referred to in the question and line-count option is absent from the booklet.',True)
r=row(9,4,True);r['question']['prompt']=[txt('Select the recursive function member(L, x) that returns True if x is present in list L, and False otherwise, including when L is empty.')];note(r,'Made the membership behavior explicit using the exact source explanation.')
setkey(row(9,5,True),[1],False,'Each even element contributes 1, while odd elements contribute nothing; the function counts even elements.')
skip(9,[6],'The code sums odd elements but none of the three original choices describes that output.',True)

# Week 10: malformed shared class code cannot be used as runnable source.
skip(10,range(1,7),'The shared Student/Group class definitions are intrinsically truncated in the original PDF (missing signatures and statements); cannot present them as executable code.')
r=row(10,7);note(r,'The source duplicates two incorrect output alternatives; both are preserved, while the correct complete output is distinct.')
q(10,9)['prompt'].insert(0,txt('Assume the current directory is writable and opening numbers.txt in write mode succeeds.'))
skip(10,range(1,6),'The Employee class implementation is already truncated in the original PDF; its constructor and methods cannot be recovered exactly.',True)
skip(10,range(6,14),'The required Rational/Product/Book class definitions are absent from the source booklet.',True)
setkey(row(10,21,True),[0,1,3],why='A missing file raises FileNotFoundError. The first, second, and fourth alternatives catch it; except ValueError does not.')
setkey(row(10,22,True),[3],False,'The first two calls print their error messages; finally prints after every call, including the successful third call, and the final print outputs 2.')

# Keep separately named source programs visually distinct.
for w,n,pa,needle in [(3,4,False,'\nx = 0'),(2,5,True,'\nflag = True')]:
 r=row(w,n,pa);s=cb(r);split=s.index(needle)
 r['question']['prompt']=intro(r)+[txt('Code 1:'),code(s[:split]),txt('Code 2:'),code(s[split:].strip())]
 note(r,'Separated the two original programs into individually labelled code blocks.')

# These panels are literal output, not runnable statements.
q(3,4,True)['prompt'][-1]['language']='text'
setkey(row(3,20),[0,1],True,'The condition filters single-digit inputs, and repeatedly replacing value reduces those matches to the last matching number (or None if none match).')
for w,n,pa in [(10,7,False),(10,9,False),(10,20,True),(10,22,True),(2,4,True),(2,29,False),(4,5,False),(4,6,True),(4,8,True),(4,25,True),(5,3,True)]:
 for option in q(w,n,pa).get('options',[]):
  for b in option:
   if b['kind']=='code':b['language']='text'

# Preserve code in options and normalize only demonstrable native-layout indentation errors.
for r in rows:
 if r.get('excluded_reason'):continue
 t=r['question']
 if t['marks']<=0:t['marks']=1;note(r,'Assigned one platform mark because the original source item has zero marks.')
 for b in t['prompt']:
  if b['kind']=='code' and b.get('language')=='python':
   old=b['value'];new=indents(old)
   if new!=old:b['value']=new;note(r,'Restored Python indentation from the native source layout.')
 for option in t.get('options',[]):
  for b in option:
   if b['kind']=='text' and re.search(r'\b(?:print|range|len|str|bool|input|set|dict|list|float|int)\s*\(|^[A-Za-z_]\w*(?:\[.*?\])?\s*=(?!=)|^[\[\{(\'\"]|[\[\]{}]|\b(?:for|return|def)\b',b['value']) and not re.match(r'^(?:The |It |A |When |If |Every |First |Number |Average |No |This |True|False|Invalid|Raises)',b['value']):
    b['kind']='code';b['language']='python'
   if b['kind']=='code' and b.get('language')=='python':b['value']=indents(b['value'])
 # The model schema is numeric-only for NAT; short-answer output remains a string.
 validate({'schema_version':'1.1','quiz_title':r['quiz_title'],'subject':'Python','section':r['section'],'questions':[t]*5})

# Do not export remaining malformed question code as runnable Python.
for r in rows:
 if r.get('excluded_reason'):continue
 for b in r['question']['prompt']:
  if b['kind']=='code' and b.get('language')=='python':
   try:ast.parse(b['value'])
   except SyntaxError as e:r['excluded_reason']='Question code is incomplete or intrinsically malformed after native-layout recovery: '+e.msg

kept=[r for r in rows if not r.get('excluded_reason')]
# Combine the small recovered Week 8 and Week 10 graded fragments, keeping provenance of every original item.
groups=collections.defaultdict(list)
for r in kept:
 title=r['quiz_title']
 if r['section']=='practice_graded' and int(re.search(r'Week (\d+)',title)[1]) in [8,10]:title='Python · Graded Assignments · Weeks 8 and 10 · Combined PYQ'
 if r['section']=='practice' and int(re.search(r'Week (\d+)',title)[1]) in [3,9]:title='Python · Practice Assignments · Weeks 3 and 9 · Combined PYQ'
 groups[(r['section'],title)].append(r)
# Same-section practice fragments combine to satisfy the mandatory minimum without invented supplements.
fragments=collections.defaultdict(list)
for key in list(groups):
 if len(groups[key])<5:fragments[key[0]].extend(groups.pop(key))
for section,rs in fragments.items():
 title='Python · '+('Practice Assignments' if section=='practice' else 'Graded Assignments')+' · Combined PYQ'
 groups[(section,title)]=rs
papers=[];destination=PROJECT/'bulk_quizzes/Python';destination.mkdir(parents=True,exist_ok=True)
for (section,title),rs in groups.items():
 if len(rs)<5:
  for r in rs:r['excluded_reason']='Fewer than five recoverable items remain in the same subject/section fragment pool.'
  continue
 sizes=balanced_sizes(len(rs));offset=0
 for part,size in enumerate(sizes,1):
  selected=rs[offset:offset+size];offset+=size
  suffix=f' · Part {part}' if len(sizes)>1 else ''
  paper={'schema_version':'1.1','quiz_title':title+suffix,'subject':'Python','section':section,'questions':[r['question'] for r in selected]};validate(paper)
  filename=re.sub(r'[^A-Za-z0-9_-]+','_',title.replace(' · ','_-_')).strip('_')+(f'_part{part}' if len(sizes)>1 else '')+'.json'
  path=destination/filename
  if path.exists():assert json.loads(path.read_text())['quiz_title']==paper['quiz_title']
  path.write_text(json.dumps(paper,ensure_ascii=False,indent=2)+'\n')
  papers.append({'path':str(path),'questions':len(selected),'source_items':[{'source':r['source'],'question_number':r['question_number'],'pages':r['pages'],'notes':r.get('recovery_notes',[])} for r in selected]})
excluded=[{'source':r['source'],'question_number':r['question_number'],'pages':r['pages'],'reason':r['excluded_reason']} for r in rows if r.get('excluded_reason')]
# Assert-only verification never executes a program taken from a booklet.
assert sum(p['questions'] for p in papers)+len(excluded)==len(rows)
seen=set()
for p in papers:
 assert 5<=p['questions']<=10
 for ref in p['source_items']:
  identity=(ref['source'],ref['question_number']);assert identity not in seen;seen.add(identity)
for r in rows:
 if r.get('excluded_reason'):continue
 t=r['question'];correct=t.get('correct_answers',[t.get('correct_answer')])
 for i,option in enumerate(t.get('options',[])):
  if i in correct:
   for b in option:
    if b['kind']=='code' and b.get('language')=='python':ast.parse(b['value'])
assert q(3,2,True)['correct_answer']==2
assert q(10,22,True)['correct_answer']==3
assert q(4,4,True)['correct_answers']==[0,3]

(ROOT/'Python_recovery_provenance.json').write_text(json.dumps({'source_question_count':len(rows),'papers':papers,'excluded':excluded},ensure_ascii=False,indent=2)+'\n')
(ROOT/'Python_recovered_candidates.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print(len(papers),'papers;',sum(p['questions'] for p in papers),'questions;',len(excluded),'excluded')
for r in excluded:print(Path(r['source']).name,r['question_number'],r['reason'])
