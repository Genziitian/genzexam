from pathlib import Path
import json,sys
from fractions import Fraction
sys.path.insert(0,str(Path(__file__).parent))
from extract_batch import validate,block,PROJECT,ROOT

def num(prompt,answer,explanation):
 return {'type':'numerical','prompt':[block(prompt)],'numerical_answer':answer,'numerical_tolerance':.01,'marks':1,'difficulty':'medium','explanation':[block(explanation)]}
def multi(prompt,options,answers,explanation):
 return {'type':'mcq_multi','prompt':[block(prompt)],'options':[[block(x)] for x in options],'correct_answers':answers,'marks':1,'difficulty':'medium','explanation':[block(explanation)]}
context=r'''The scores of a student in mathematics, physics and chemistry in her class-12 board exams are $m,p,c$ respectively, where each score is out of 100. She has applied for three engineering streams in a college. Each stream assigns different weights to these three subjects to calculate her final score, which is again out of 100.
For example, the weight given to mathematics, physics and chemistry could be $0.2,0.7,0.1$ respectively by a stream. These weights are then multiplied with the corresponding scores to get the final score. Concretely, if the student has scored $85,78,40$ in the three subjects, her final score for this stream is $0.2\times85+0.7\times78+0.1\times40=75.6$.
This is called a weighted average. Note that the weights always sum to 1. Now, the weights assigned by the three streams for mathematics, physics and chemistry, in this order, are given below:
Stream-1: $0.2,0.7,0.1$
Stream-2: $0.5,0.3,0.2$
Stream-3: $0.1,0.4,0.5$
The final score of the student in stream-1 is 81. It is 83 in stream-2 and 76 in stream-3. We wish to find the student's marks in the three subjects.'''
A=r'\begin{bmatrix}0.2&0.7&0.1\\0.5&0.3&0.2\\0.1&0.4&0.5\end{bmatrix}'
qs=[
 multi(r'''Match the systems of linear equations in Column A with their number of solutions in Column B and their geometric representation in Column C. Which of the following are true?
Column A:
i) $x+y=3,\ x-y=-3$
ii) $x+y+z=1,\ x+y+z=7$
iii) $z=0,\ x+y+z=1$
Column B: a) Infinite solutions; b) Unique solution; c) No solution.
Column C (transcription of the three source diagrams): 1) Two distinct parallel planes; 2) Two planes intersecting in a line; 3) Two straight lines intersecting in a point.''',
 [r'i) $\to$ b) $\to$ 3)',r'i) $\to$ a) $\to$ 3)',r'ii) $\to$ c) $\to$ 2)',r'ii) $\to$ c) $\to$ 1)',r'iii) $\to$ a) $\to$ 2)',r'iii) $\to$ a) $\to$ 1)'],[0,3,4],
 r'''i) Substitution gives $y=3,x=0$, so the two lines have a unique intersection $(0,3)$.
ii) The same expression $x+y+z$ cannot equal both 1 and 7. The planes are parallel and distinct, giving no solution.
iii) Setting $z=0$ in the second equation gives $x+y=1$. Every point on this line is a solution, so the planes intersect in a line and there are infinitely many solutions.'''),
 num(r'Suppose $\det(4A)=n\det(A)$ for every real $5\times5$ matrix $A$. What is the value of $n$?',1024,r'Multiplying all five rows by 4 multiplies the determinant by $4^5=1024$. Thus $\det(4A)=1024\det(A)$.'),
 num(r'For every square matrix $A$ satisfying $A^2=A$, the identity $(I+A)^3-10A=I+mA$ holds, where $I$ is the identity matrix of the same order. Find $m$.',-3,r'Since $A^2=A$, we also have $A^3=A$. Expanding gives $(I+A)^3=I+3A+3A^2+A^3=I+7A$. Subtracting $10A$ gives $I-3A$, so $m=-3$.'),
 num(r'If $A=\begin{bmatrix}20&30&40\\8&16&24\\8&10&12\end{bmatrix}$, what is $\det(A)$?',0,r'Expanding along the first row gives $\det(A)=20(16\cdot12-24\cdot10)-30(8\cdot12-24\cdot8)+40(8\cdot10-16\cdot8)=-960+2880-1920=0$.'),
 num(r'Let $A$ be a square matrix of order 3 and $B$ be obtained by adding 6 times the first row of $A$ to its third row, then adding 6 times its second row to its first row. If $\det(A)=5$, find $\det(4A^2B^{-1})$.',320,r'Adding a multiple of another row does not change a determinant, so $\det(B)=5$ and $\det(B^{-1})=1/5$. Therefore $\det(4A^2B^{-1})=4^3(\det A)^2\det(B^{-1})=64\cdot25/5=320$.'),
 num(r'If $A=\begin{bmatrix}1&1&1\\1&1&1\\1&1&1\end{bmatrix}$, what is the sum of the diagonal elements of $A^7$?',2187,r'For this matrix, $A^2=3A$ and $A^k=3^{k-1}A$ for every positive integer $k$. Each diagonal entry of $A^7$ is $3^6=729$, so the sum is $3\cdot729=2187$.'),
 num(r'Let $A=[a_{ij}]$ be a square matrix of order 3, where $a_{ij}=i+3j$ for $i,j\in\{1,2,3\}$. Find $\det(A)$.',0,r'The matrix is $A=\begin{bmatrix}4&7&10\\5&8&11\\6&9&12\end{bmatrix}$. Expanding gives $4(8\cdot12-11\cdot9)-5(7\cdot12-10\cdot9)+6(7\cdot11-8\cdot10)=4(-3)-5(-6)+6(-3)=0$.'),
 multi(context+'\n\n'+r'This is framed as a system of linear equations. Select all true options concerning the coefficient matrix if the vector of unknowns is $\begin{bmatrix}m\\p\\c\end{bmatrix}$. Assume the first equation corresponds to stream-1, the second to stream-2, and the last to stream-3.',
 [r'The first row is $0.2,0.7,0.1$.',r'The last row is $0.1,0.4,0.5$.',r'The first column is $0.2,0.7,0.1$.',r'The middle column is $0.5,0.3,0.2$.'],[0,1],
 r'The equations are $0.2m+0.7p+0.1c=81$, $0.5m+0.3p+0.2c=83$, and $0.1m+0.4p+0.5c=76$. Hence the coefficient matrix is $A='+A+r'$. Its first and last rows are as stated in the first two options; its first column is $(0.2,0.5,0.1)^T$ and its middle column is $(0.7,0.3,0.4)^T$.'),
 num(context+'\n\n'+r'Find $\dfrac{m+p+c}{3}$.',80,r'From the first equation, $c=810-7p-2m$. Substitution in the second gives $m=11p-790$. Substitution in the third gives $-3.1p-0.9m=-329$, so $-13p=-1040$ and $p=80$. Thus $m=90$ and $c=70$. The required average is $(90+80+70)/3=80$.'),
 num(context+'\n\n'+r'Find $\det(A)$, where $A='+A+r'$ is the coefficient matrix with equations ordered stream-1, stream-2, stream-3 and unknowns ordered $m,p,c$.',-.13,r'Expanding along the first column, $\det(A)=0.2(0.3\cdot0.5-0.4\cdot0.2)-0.5(0.7\cdot0.5-0.4\cdot0.1)+0.1(0.7\cdot0.2-0.3\cdot0.1)=0.014-0.155+0.011=-0.13$.')
]
paper={'schema_version':'1.1','quiz_title':'Mathematics 2 · Graded Assignment · Week 1 · May 2024','subject':'Mathematics 2','section':'practice_graded','questions':qs}
qs[0]['prompt']=[block('Match the systems of linear equations in Column A with their number of solutions in Column B and their geometric representation in Column C.'),{'kind':'image','url':'/assets/exam-examples/question-crops/mathematics-2/ga1/q1-table.png','alt':'Original matching table with linear systems, numbers of solutions, and three geometric diagrams.'},block('Which of the following are true?')]
qs[0]['options'][0]=[{'kind':'image','url':'/assets/exam-examples/question-crops/mathematics-2/ga1/q1-option1.png','alt':'i) maps to b) maps to 3).'}]
validate(paper)
def det(a):return a[0][0]*(a[1][1]*a[2][2]-a[1][2]*a[2][1])-a[0][1]*(a[1][0]*a[2][2]-a[1][2]*a[2][0])+a[0][2]*(a[1][0]*a[2][1]-a[1][1]*a[2][0])
assert det([[20,30,40],[8,16,24],[8,10,12]])==0
assert det([[4,7,10],[5,8,11],[6,9,12]])==0
weights=[[Fraction(v,10) for v in row] for row in [[2,7,1],[5,3,2],[1,4,5]]]
assert det(weights)==Fraction(-13,100)
assert [sum(a*b for a,b in zip(row,[90,80,70])) for row in weights]==[81,83,76]
assert 4**5==1024 and 4**3*25/5==320 and 3**7==2187
out=PROJECT/'bulk_quizzes/Mathematics 2/Mathematics_2_-_Graded_Assignment_-_Week_1_-_May_2024.json'
assert not out.exists() or json.loads(out.read_text())['quiz_title']==paper['quiz_title']
out.parent.mkdir(exist_ok=True,parents=True);out.write_text(json.dumps(paper,ensure_ascii=False,indent=2)+'\n')
notes={'output':str(out),'source':'/Users/tusharrrsingh/Downloads/all/Maths 2/Maths 2 - Graded Assignment 1 (Week 1) - Gen-Z IITian - booklet.pdf','source_questions':list(range(1,11)),'visually_reviewed_pages':[3,4,5,6,7,8,9,10],'editorial_notes':[{'question':1,'note':'Attached the original source table with all three geometric diagrams and an original option crop. Preserved all six choices and original answer set.'},{'question':3,'note':'Source stem omits I on the RHS, but its worked solution uses I+mA and derives m=-3. Restored the I from that solution and made the identity apply to every idempotent A.'},{'question':7,'note':'Normalized the source 1i+3j to i+3j; source matrix entries and determinant are preserved.'}],'default_fields':{'marks':1,'difficulty':'medium'},'checks':['Schema and 5-to-10 size validation','Exact rational determinant and weighted-score checks','All source questions retained; no supplement questions']}
(ROOT/'Mathematics_2_GA1_provenance.json').write_text(json.dumps(notes,indent=2,ensure_ascii=False)+'\n')
print(out)
