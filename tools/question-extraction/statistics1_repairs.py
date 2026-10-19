"""Audited repairs using only the parameters and data present in Statistics 1 sources."""
import copy,re,math
from fractions import Fraction

FORMULAS={
 (2,4):('(a+b+d)/(a+b+d+125)','The three unspecified academy counts sum to a+b+d, and the total count is a+b+d+50+75.'),
 (3,1):('ceil((6*a+2*b-3*c-5*m)/(4*m-a-b-c-d))','The weighted-mean equation is m(4x+5)=x(a+b+c+d)+6a+2b−3c. Solve for x and round upward as requested.'),
 (3,2):('m+(x-p)/N','Replacing the incorrectly recorded p by x changes the total by x−p, so the corrected mean is m+(x−p)/N.'),
 (3,3):('s^2+(x^2-p^2-N*((m+(x-p)/N)^2-m^2))/(N-1)','The original sum of squared values is (N−1)s²+Nm². Replace p² by x², then subtract N times the square of the corrected mean and divide by N−1.'),
 (3,4):('unchanged','Adding the same constant to all observations leaves every deviation from the mean unchanged; therefore sample variance is unchanged.'),
 (4,7):('(c+g)/(a+b+c+d+e+f+g+h)','Dull students are c+g, divided by all students in the table.'),
 (4,8):('(e+f+g+h)/(a+b+c+d+e+f+g+h)','The poor-economic-condition row has e+f+g+h students, divided by the table total.'),
 (4,9):('d/(a+b+c+d)','The denominator includes all students with good economic conditions; the borderline cell is d.'),
 (4,10):('100*e/(a+e)','Among bright students, the poor-economic-condition count is e and the total is a+e.'),
 (4,11):('100*b/(b+f)','Among average students, the good-economic-condition count is b and the total is b+f.'),
 (5,1):('m!/(m-n)!','Assign a distinct cover colour to each labelled register: m choices, then m−1, continuing for n registers.'),
 (5,2):('2^n-1','Every subset of classmates is possible except the empty subset.'),
 (5,3):('9^m*10^n','Each of the m alphabet positions has 9 choices; each of the n digit positions has 10 choices, with repetition allowed.'),
 (5,4):('9^m*10^n+9!/(9-b)!*10!/(10-a)!','Add the VIP count to the normal-plate count. The normal plate has a distinct digits and b distinct letters.'),
 (5,7):('3^N','Each student has three possible responses: liked, disliked, or no response.'),
 (5,12):('x!*y!','Treat the x men as one block; arrange this block with y women around a circle in y! ways, then arrange the men inside their block in x! ways.'),
 (6,2):('(n+2)*(n+1)/2','There are n+2 stations, including both endpoints. Each unordered pair needs one ticket when direction is ignored.'),
 (6,3):('binom(n,m)-binom(n-2,m-2)','Subtract selections containing both A and B from all selections of m friends.'),
 (6,4):('4*(m-2)!','There are 2 choices for the day of C1 and then 2 admissible choices for C2. Arrange all remaining clothes freely.'),
 (6,6):('m*binom(n,n-m-1)','Choose the single district-level player in m ways, then n−m−1 of the n state-level players.'),
 (7,2):('2^(m-1)','A must be included, while each of the remaining m−1 options can independently be included or omitted.'),
 (7,4):('1-(a+p)/100','Tennis players are contained in table tennis and excluded from badminton. Since the given n students belong to the union of the three teams, table-tennis-only students form the complement of badminton and tennis.'),
 (7,5):('e/f-a/b+c/d','Use P(Q1∪Q2)=P(Q1)+P(Q2)−P(Q1∩Q2), then solve for P(Q2).'),
 (7,6):('1-z','The probability of a union and its complement sum to one.'),
 (7,7):('x*y*z/binom(x+y+z,3)','Choose one shirt, one pair of pants and one T-shirt, divided by all unordered choices of three clothes.'),
 (7,8):('binom(26,b)*binom(26,c)/binom(52,a)','Choose b black and c red cards from the 26 cards of each colour, divided by all a-card hands.'),
 (8,3):('(x*p+q+r)/(100*(x+2))','Factory production weights are x:1:1. Apply the law of total probability to the defect percentages.'),
 (8,4):('q/(x*p+q+r)','Bayes’ formula divides the defective contribution from factory B by the total defective contribution.'),
 (8,5):('1-(1-a/b)*(1-c/d)*(1-e/f)','The task is unfinished only if all three independent people fail.'),
 (8,6):('(1-n)/m','Independence gives P(Aᶜ∩Bᶜ)=P(Aᶜ)P(Bᶜ)=mx. This is the complement of the given union, with probability 1−n.'),
 (9,1):('m-n^2','A CDF must satisfy F(n)=1 at the largest support value; hence (n²+k)/m=1.'),
 (9,6):('1-x/100','The only value exceeding n−1 is n, which has probability x/100.'),
 (9,7):('1-m/n','The infinite geometric series sums to 1/(1−m/n); normalization requires k=1−m/n, provided 0≤m/n<1.'),
 (9,8):('(1-m/n)*(m/n)^2','With k=1−m/n from normalization, substitute X=2 into the mass function.'),
 (11,3):('sum(i=x..y,binom(y,i)*(a/(a+b))^i*(b/(a+b))^(y-i))','The number of rounds won by A is Binomial(y,a/(a+b)); sum its mass function from x wins through y wins.'),
 (11,4):('b*(x+1)/(a*(n-x)+b*(x+1))','Divide the Binomial probability at x+1 by the probability at x, set the ratio to b/a, and solve for p.'),
 (11,5):('1-(v/e)^n','Binomial mean np=e and variance np(1−p)=v imply 1−p=v/e. Subtract the probability of no sixes from one.'),
 (11,6):('1-(1-1/m)^n-(n/m)*(1-1/m)^(n-1)','For Binomial(n,1/m), subtract the probabilities of zero and one successes from one.'),
 (12,1):('e^2-3*v','For Uniform[a,b], e=(a+b)/2 and v=(b−a)²/12. Therefore ab=((a+b)²−(b−a)²)/4=e²−3v.'),
 (12,8):('m+6-12/p','Uniform variance 12 implies b−a=12. Since F(m)=1/p, a=m−12/p; the mean a+6 is m+6−12/p.'),
}
EXCLUDE={
 (2,8):'All three source options are actually blank; the charts were omitted from their choice rows.',
 (3,5):'No observation values or percentile convention are supplied for the symbolic dataset.',
 (3,6):'The actual dataset is absent; numerical IQR cannot be determined.',
 (3,7):'The actual dataset is absent; numerical outlier count cannot be determined.',
 (3,9):'Required stem-and-leaf plot is absent; the source attaches a card-frequency table instead.',
 (3,10):'Required ratings plot is absent; the source attaches a card-frequency table instead.',
 (3,100):'Phantom Q100 starts inside a previous solution; genuine embedded production subquestions are recovered separately.',
 (4,1):'Only symbolic sales a,c,e,g,i,k,m are provided; no numeric sales or source formula answer are supplied.',
 (4,2):'Only symbolic sales b,d,f,h,j,l,n are provided; no numeric sales or source formula answer are supplied.',
 (4,3):'Numeric covariance requires actual sales values; only symbolic placeholders and a blank key are present.',
 (4,4):'Numeric correlation requires actual sales values; only symbolic placeholders and a blank key are present.',
 (4,5):'The claimed strength of correlation cannot be established from a table containing only arbitrary letters.',
 (4,6):'Influence of dealer location cannot be established from a table containing only arbitrary letters.',
 (5,8):'The source introduces an undefined z in the denominator but gives an answer independent of z; the intended expression cannot be uniquely recovered.',
 (7,3):'The stated marginal prediction probabilities do not determine joint success probabilities; independence is not stated.',
 (7,10):'Disjoint events need not satisfy any of the offered inequalities between P(A) and P(B). No option is always true.',
 (8,2):'The probability of matching wrong scores is not specified as conditional on both predictions being wrong, but the source key requires that additional interpretation.',
 (8,8):'The referenced researchers/intelligence-level contingency table is absent from the source.',
 (8,9):'The referenced researchers/intelligence-level contingency table is absent from the source.',
 (8,10):'The referenced researchers/intelligence-level contingency table is absent from the source.',
 (8,51):'Phantom Q51 starts inside a previous solution; genuine embedded teacher-quiz subquestions are recovered separately.',
 (9,2):'The lucky-draw prize/ticket values are missing or garbled in the stem, so the intended probability is not determined.',
 (9,3):'The number of possible photographer counts depends on n,x,m; the keyed m+1 requires unstated bounds ensuring enough photographers and journalists.',
 (9,12):'The options are bare unexplained numbers 17,21,17,23 rather than probability mass functions.',
 (10,2):'The first part of the shared sign-sequence experiment is absent; the context starts mid-sentence “last sign”.',
 (10,4):'The random-walk context omits the probability of moving right and starts mid-sentence. The keyed 1.4 is not determined.',
 (10,5):'The random-walk context omits the probability of moving right; the keyed variance 6.72 is not determined.',
 (11,8):'The referenced Binomial probability table needed to determine p is absent.',
 (12,2):'Single-choice options B and D are identical n³−m³; the source therefore has two correct alternatives.',
 (12,3):'The conditional-uniform formula depends on the relative order and support of m and n, which are not specified; the keyed formula assumes unstated ordering.',
}

def apply_native(d,n,q,error,candidate,api):
 w=api.week(d);key=(w,n);notes=[]
 if key in EXCLUDE:return None,EXCLUDE[key],notes
 if key in FORMULAS:
  answer,solution=FORMULAS[key]
  if q is None:q={'prompt':[],'marks':1,'difficulty':'medium'}
  q={k:v for k,v in q.items() if k in ['prompt','marks','difficulty']}
  original=copy.deepcopy(candidate['question']['prompt']) if candidate and candidate['question'] else []
  prompt='\n'.join(b.get('value','') for b in original)
  prompt=re.sub(r'\([^)]*(?:correct|decimal|accuracy|Enter|answer up)[^)]*\)','',prompt,flags=re.I)
  prompt=prompt.replace('CONTEXT\n','').strip()
  if key in [(8,3),(8,4)]:
   prompt='Factory A produces x times as many items as factory B, while B and C produce equal numbers. Their defective proportions are p%,q%,r%, respectively. All items are pooled and one item is selected randomly.\n'+('What is the probability that the item is defective?' if n==3 else 'Given that the item is defective, what is the probability that factory B produced it?')
  if key==(8,5):prompt=prompt[prompt.find('A particular task'):]
  if key==(8,6):prompt=prompt[prompt.find('If A and B are two independent'):]
  if key==(6,4):prompt=prompt[:prompt.find('C1 must be used at either')]
  if key==(7,5):prompt='The probability of clearing Quiz 1 is a/b, clearing both Quiz 1 and Quiz 2 is c/d, and clearing at least one quiz is e/f. What is the probability of clearing Quiz 2?'
  if key==(9,8):prompt='For x=0,1,2,… let P(X=x)=k(m/n)^x, where 0≤m/n<1 and k makes the total probability one. Find P(X=2).'
  if key==(9,7):prompt='For x=0,1,2,… let P(X=x)=k(m/n)^x, where 0≤m/n<1. Find k so this is a probability mass function.'
  if key==(9,1):prompt='A discrete random variable X takes values 1,2,…,n with CDF F(x)=(x²+k)/m at those values. Find k.'
  if key==(3,4):prompt='The observations x₁,x₂,…,xₙ are retail prices. How does the sample variance change if the same constant c is added to every observation?'
  q.update(type='short_answer',prompt=[api.text(prompt),api.text('Give an expression in the stated parameters.' if key!=(3,4) else 'State how the sample variance changes.')],acceptable_answers=list(dict.fromkeys([answer,answer.replace('*',''),answer.replace('^','**')])),explanation=[api.text(solution)])
  if key==(3,4):q['acceptable_answers']=['unchanged','same','does not change','sample variance is unchanged']
  notes.append('Corrected a parameter-only numerical item to short_answer; accepted formula variants use only the original parameters. Formula grading is exact-match.')
  if key in [(8,3),(8,4)]:notes.append('Restored the exact factory scenario misplaced under source questions5/6.')
  return q,None,notes
 if q is None and key in [(8,13),(9,9),(9,10)] and candidate and candidate['question']:
  q=copy.deepcopy(candidate['question'])
 if q is None:return q,error,notes
 if key==(2,6):q['correct_answer']=4;q['explanation']=[api.text('The unspecified counts a,b,d could exceed75. Therefore the mode cannot be identified from the supplied table; choose Insufficient data.')];notes.append('Corrected mode key to Insufficient data because three category counts are unspecified.')
 if key==(4,12):q['prompt'].append(api.text('Assume Anjali’s sales are not constant across the six months.'));notes.append('Made the nonzero-variance condition explicit so Pearson correlation is defined.')
 if key==(9,4):
  q['options']=[[api.text(t)] for t in ['Number of tires produced every30minutes.','Number of popcorn kernels in a1kg container.','Time between customers entering a checkout lane.','Amount of rain recorded at an airport in one day.','Amount of liquid in a2litre bottle.','Number of no-shows for every1000airline reservations.']];q['correct_answers']=[0,1,5];notes.append('Separated inline source option f from option e; corrected key to include the discrete no-show count.')
 if key==(11,2):
  q['type']='mcq_multi';q.pop('correct_answer',None);q['correct_answers']=[2,3]
  q['options']=[[api.text(t)] for t in ['E(X)≤Var(X)','E(X)<Var(X)','E(X)≥Var(X)','E(X)>Var(X)','Var(X)≤SD(X)','Var(X)≥SD(X)']]
  notes.append('The source asks statement/s; both≥and>are always true. Corrected MCQ to multi-select, restored inline option f and keysC,D.')
 if key==(10,3):q['prompt']=[api.text('Let Y=9S+1 for a random variable S with finite mean and variance. Which statements are true?')];notes.append('Removed an irrelevant truncated experiment; the complete defined transformation is sufficient for this expectation/variance question.')
 if key==(11,15):
  q['prompt']=[api.text('Each of five products independently passes inspection with probability0.40. Let X count the products that pass. Identify the distribution of X.')]
  q['options']=[[api.text(t)] for t in ['Binomial(5,0.6)','Binomial(5,0.4)','Bernoulli(0.6)','Bernoulli(0.4)']];q['correct_answer']=1;notes.append('Removed the stem and following subquestion accidentally stored as choices; corrected distribution key to Binomial(5,0.4).')
 if key==(11,14):return None,'Compound numerical subquestions incorrectly formatted as MCQ; recovered separately.',notes
 if key==(7,11):return None,'Compound numerical subquestions incorrectly formatted as MCQ; recovered separately.',notes
 if key==(8,13):q.update(type='numerical',numerical_answer=float(Fraction(39,51)*Fraction(26,50)*Fraction(13,49)),numerical_tolerance=.001);notes.append('Computed missing key using the explicit group-allocation probabilities in the adjacent original solution.')
 if key==(9,9):q.update(type='numerical',numerical_answer=0,numerical_tolerance=0);notes.append('Computed missing key by enumerating the hypergeometric probabilities: X=0has the least probability.')
 if key==(9,10):q.update(type='numerical',numerical_answer=1,numerical_tolerance=.01);notes.append('Normalization gives5k²−3k−2=0; the positive admissible solution is1.')
 return q,None,notes
