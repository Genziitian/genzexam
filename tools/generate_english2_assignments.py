#!/usr/bin/env python3
"""
Generate verified Schema 1.1 JSON papers for English 2:
- 12 Graded Assignments (GA Week 1 to 12) -> section: "practice_graded"
- 12 Practice Assignments (PA Week 1 to 12) -> section: "practice"

All papers strictly follow:
1. 5 <= Q <= 10 questions per paper.
2. 100% self-contained questions with context/excerpts attached.
3. Clean options, 0-indexed correct_answer integer, marks, difficulty, explanations.
4. Schema version 1.1.
"""

import os
import json

OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'bulk_quizzes', 'English 2')
os.makedirs(OUT_DIR, exist_ok=True)

def opt(text):
    return [{"kind": "text", "value": text}]

def prompt(text, context=None):
    blocks = []
    if context:
        blocks.append({"kind": "text", "value": context})
    blocks.append({"kind": "text", "value": text})
    return blocks

def mcq(stem, options, correct_idx, explanation="", context=None, marks=1, difficulty="medium"):
    return {
        "type": "mcq_single",
        "prompt": prompt(stem, context),
        "options": [opt(o) for o in options],
        "correct_answer": correct_idx,
        "marks": marks,
        "difficulty": difficulty,
        "explanation": [{"kind": "text", "value": explanation or "Refer to the course materials and lecture notes."}]
    }

def save_quiz(title, section, week, questions, filename):
    data = {
        "schema_version": "1.1",
        "quiz_title": title,
        "subject": "English 2",
        "section": section,
        "week": week,
        "questions": questions
    }
    path = os.path.join(OUT_DIR, filename)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"Saved {filename} ({len(questions)} Qs, section={section}, week={week})")

# ==============================================================================
# GRADED ASSIGNMENTS (GA WEEKS 1 - 12)
# ==============================================================================

MANDELA_SPEECH = (
    "Context: Listen to the speech by Nelson Mandela:\n"
    "Audio link: https://drive.google.com/file/d/15DjnS5EOivAr3pBfSNG4YAYJn5aAJihz/view?usp=sharing\n\n"
    "\"Sport has the power to change the world. It has the power to inspire. It has the power to "
    "unite people in a way that little else does. It speaks to youth in a language they understand. "
    "Sport can create hope where once there was only despair. It is more powerful than governments "
    "in breaking down racial barriers. It laughs in the face of all types of discrimination. The heroes "
    "standing with me are examples of this power. They are valiant not only on the playing field but "
    "also in the community both local and international...\""
)

AUDIO_PAUSE_CONTEXT = (
    "Context: Listen to the audio on pause-breaks and sentence intonation:\n"
    "Audio link: https://drive.google.com/file/d/1deTtFcM62FbL-QkKiY8euI9pXy25Wudf/view?usp=sharing"
)

# GA Week 1 (10 Qs)
ga_week1_qs = [
    mcq("Presentations are greatly enhanced by varying the tone of voice to emphasize aspects of the content.",
        ["True", "False"], 0,
        "Varying the tone of voice, pitch, and volume helps retain audience engagement and highlights key points."),
    mcq("Which of the following is NOT true about the statement: 'Maintaining eye contact with the audience while presenting is critical to ______'?",
        ["Credibility", "Rapport", "Relaxing", "Involving the audience"], 2,
        "Eye contact builds credibility, rapport, and audience involvement, but does not serve to relax the presenter."),
    mcq("Identify the stressed syllable in the word 'Together':",
        ["'Together", "To'gether", "Toge'ther", "Tog'ether"], 1,
        "In 'together', stress falls on the second syllable: /təˈɡeð.ər/.", context=MANDELA_SPEECH),
    mcq("Identify the stressed syllable in the word 'Represent':",
        ["Re'present", "'Represent", "Repre'sent", "Rep'resent"], 2,
        "In 'represent' (verb), primary stress falls on the third syllable: /ˌrep.rɪˈzent/.", context=MANDELA_SPEECH),
    mcq("Identify the stressed syllable in the word 'Atmosphere':",
        ["At'mosphere", "Atmo'sphere", "A'tmosphere", "'Atmosphere"], 3,
        "Nouns often take stress on the first syllable. In 'atmosphere', stress is on the first syllable: /ˈæt.məs.fɪər/.", context=MANDELA_SPEECH),
    mcq("Which syllable in the word 'community' has the long vowel?",
        ["No long vowels in the word", "First", "Second", "Fourth"], 0,
        "Phonetic transcription is /kəˈmjuː.nə.ti/. The vowel in the second syllable is often classified as a glide/diphthong or tense vowel, with no pure long vowel."),
    mcq("How many vowel sounds are there in the word 'create'?",
        ["0", "1", "2", "3"], 2,
        "/kriːˈeɪt/ has two vowel sounds: /iː/ and /eɪ/."),
    mcq("In the word 'deserve', the second syllable has a short vowel.",
        ["True", "False"], 1,
        "/dɪˈzɜːv/ contains the long central vowel /ɜː/ in the second syllable, so the statement is false."),
    mcq("Choose the appropriate pause for the sentence: 'If you haven’t found it yet keep looking and don’t settle'",
        [
            "If you haven’t found it yet keep looking/ and don’t settle//",
            "If you haven’t found it yet/ keep looking/ and don’t settle//",
            "If you haven’t/ found it yet/ keep looking/ and don’t settle//",
            "If you haven’t found it yet/ keep looking/ and don’t/ settle//"
        ], 1,
        "Natural speech chunking places tone unit pauses after the conditional clause and between coordinated imperatives.", context=AUDIO_PAUSE_CONTEXT),
    mcq("Choose the appropriate pause for the sentence: 'And most important have the courage to follow your heart and intuition'",
        [
            "And most important/ have the courage to follow your heart and intuition//",
            "And most important/ have the courage/ to follow your heart and intuition//",
            "And most important/ have the courage/ to follow your heart/ and intuition//",
            "And/ most important/ have the courage to follow your heart and intuition//"
        ], 0,
        "In spoken English, introductory adverbials like 'And most important' form their own tone unit followed by a pause.", context=AUDIO_PAUSE_CONTEXT),
]

# GA Week 2 (10 Qs)
ga_week2_qs = [
    mcq("‘This book is necessary for me to do my research.’ In this sentence, the subordinate clause is:",
        ["Is necessary", "This book is necessary", "For me", "For me to do my research"], 3,
        "‘For me to do my research’ is a non-finite dependent clause serving as a complement to 'necessary'."),
    mcq("A simple sentence has ______.",
        ["Two independent clauses", "An independent clause and many dependent clauses", "An independent clause", "All of the above"], 2,
        "A simple sentence consists of exactly one independent clause and no dependent clauses."),
    mcq("‘The vegetables, which I bought only yesterday, are beginning to spoil.’ The independent clause is:",
        ["The vegetables which I bought only yesterday", "The vegetables are beginning to spoil", "Which I bought only yesterday", "Which I bought only yesterday are beginning to spoil"], 1,
        "‘The vegetables are beginning to spoil’ can stand alone as a complete sentence; ‘which I bought only yesterday’ is a dependent relative clause."),
    mcq("‘The CEO of the company along with the board members passed a new resolution yesterday’. This sentence has two adjuncts.",
        ["True", "False"], 0,
        "The prepositional phrase 'along with the board members' (or 'of the company') and the time adverbial 'yesterday' function as adjuncts."),
    mcq("‘The book with the blue cover on the shelf in the drawing room is the one that you gave me.’ This sentence has ____ adjuncts.",
        ["1", "2", "3", "4"], 2,
        "The three adjunct prepositional phrases are: ‘with the blue cover’, ‘on the shelf’, and ‘in the drawing room’."),
    mcq("‘Documentaries about animals which highlight their rapidly-changing habitats are of the utmost importance in order to be able to prevent environmental destruction.’ This sentence has 4 clauses.",
        ["True", "False"], 1,
        "The sentence has fewer than 4 clauses (the main matrix clause and the relative and purpose clauses)."),
    mcq("‘The garba celebrations, which were held for a week, were astonishingly grand for a miniscule village which was located in the hinterlands of the state.’ This sentence has __ clauses in total.",
        ["1", "2", "3", "4"], 2,
        "Main clause: ‘The garba celebrations were astonishingly grand...’; Subordinate clause 1: ‘which were held for a week’; Subordinate clause 2: ‘which was located...’. Total = 3 clauses."),
    mcq("Identify the type of subordinate clause in: ‘The house where we live has a lot of trees’",
        ["Noun clause", "Adjectival clause", "Adverbial clause", "Prepositional clause"], 1,
        "‘where we live’ is a relative (adjectival) clause modifying the noun ‘house’."),
    mcq("Identify the type of subordinate clause in: ‘The patient had died before the doctor came’",
        ["Noun clause", "Adjectival clause", "Adverbial clause", "Noun phrase"], 2,
        "‘before the doctor came’ is an adverbial clause of time modifying the verb ‘had died’."),
    mcq("Identify the type of subordinate clause in: ‘Whoever sent us this letter should have signed his or her name.’",
        ["Noun clause", "Adjectival clause", "Adverbial clause", "Coordinate clause"], 0,
        "‘Whoever sent us this letter’ is a nominal (noun) clause functioning as the grammatical subject of the sentence."),
]

# GA Week 3 (9 Qs)
ga_week3_qs = [
    mcq("Indicative, subjunctive, and imperative are types of:",
        ["verb aspect", "verb mood", "adverb", "verb tense"], 1,
        "Indicative, subjunctive, and imperative are the primary grammatical moods in English."),
    mcq("Simple, progressive, and perfect are types of:",
        ["verb aspect", "verb tense", "adverb", "verb mood"], 0,
        "Simple, continuous/progressive, and perfect are grammatical aspects expressing how an action extends over time."),
    mcq("Which of the following is the most appropriate and polite way of requesting additional academic support?",
        [
            "Can you teach me this?",
            "I am struggling with this and was wondering whether you would be able to support me, if you have the time.",
            "Do you have the time to take extra classes?",
            "Are you interested in teaching outside the classroom?"
        ], 1,
        "Polite requests use modal distancing ('was wondering whether you would be able to...') and acknowledge the recipient's time constraints."),
    mcq("Which of the following is the most polite and professional way of clarifying a doubt during a lecture?",
        [
            "Could you please repeat that? I did not understand it the first time.",
            "Repeat that",
            "Can you repeat it?",
            "You are not being very clear"
        ], 0,
        "Using 'Could you please...' with an honest, respectful explanation is polite academic communication."),
    mcq("Which of the following is an example of middle clipping?",
        ["gym", "flu", "phone", "gram"], 1,
        "‘Flu’ is formed by clipping both the front and back of ‘influenza’ (middle clipping)."),
    mcq("Which of the following is the most appropriate way of requesting lecture notes from an instructor?",
        [
            "Please share notes",
            "We will not be able to study without your notes",
            "Would it be possible for us to get lecture notes after the class? It will help us prepare better.",
            "I beg of you to share your lecture notes"
        ], 2,
        "Formal academic requests use indirect inquiry ('Would it be possible...') stating constructive rationale."),
    mcq("Which word formation process creates 'flu' from 'influenza'?",
        ["blending", "clipping", "borrowing", "compounding"], 1,
        "Clipping is the word formation process of shortening a polysyllabic word without changing its meaning."),
    mcq("‘-s’ and ‘-ies’ in ‘dogs’ and ‘babies’ are:",
        ["Plural markers", "Morphemes", "Both of the above", "None of the above"], 2,
        "They are inflectional morphemes that function as plural markers."),
    mcq("‘Conceive, congregate, consult, convivial’ are words formed with:",
        ["Prefixes", "Infixes", "Suffixes", "None of the above"], 0,
        "All four words share the Latin prefix 'con-' (meaning together or with)."),
]

# GA Week 4 (5 Qs)
ga_week4_qs = [
    mcq("A good essay needs revision.",
        ["True", "False"], 0,
        "Revision is an indispensable stage in academic writing to polish flow, cohesion, and grammatical precision."),
    mcq("20–25 percent of time and words may be given to illustrations and supporting examples while writing an essay.",
        ["True", "False"], 0,
        "Substantial essay weight is dedicated to evidence, examples, and illustrations to substantiate claims."),
    mcq("Sentences and paragraphs must not remain connected while writing an essay.",
        ["True", "False"], 1,
        "Essays require strong coherence, transitions, and cohesive links between sentences and paragraphs."),
    mcq("A good essay must not have a synopsis or outline.",
        ["True", "False"], 1,
        "Planning an outline/synopsis before drafting is an established academic writing best practice."),
    mcq("When we write to argue, the final part usually takes an overview and reaches an acceptable conclusion.",
        ["True", "False"], 0,
        "Argumentative writing synthesizes the evaluated perspectives in the conclusion to deliver a well-reasoned judgment."),
]

# GA Week 5 (10 Qs)
ga_week5_qs = [
    mcq("‘Preetham has been returning late every evening. He really ____ speak to his boss about leaving a little earlier.’",
        ["Ought to", "Can", "Might", "Will"], 0,
        "‘Ought to’ expresses moral obligation or advisory recommendation that something should be done."),
    mcq("Identify the modal auxiliary in: 'This might be your can of water.'",
        ["can", "be", "might", "your"], 2,
        "‘Might’ is the modal auxiliary expressing epistemic possibility; ‘can’ is used here as a noun."),
    mcq("Identify the modal auxiliary in: 'She could be here tomorrow.'",
        ["be", "could", "here", "All of the above"], 1,
        "‘Could’ is the modal auxiliary indicating possibility."),
    mcq("The modal auxiliary ‘may’ denotes number, person, and gender.",
        ["True", "False"], 1,
        "Modal auxiliaries in English are defective verbs: they do not take -s for third person and do not inflect for number, person, or gender."),
    mcq("‘Could you shut the door while leaving the room?’ Here ‘could’ denotes:",
        ["Permission", "Ability", "Request", "Suggestion"], 2,
        "‘Could you...’ in an interrogative sentence is a polite formula for making a request."),
    mcq("‘Can you do everything on your own?’ Here ‘can’ denotes:",
        ["possibility", "ability", "suggestion", "request"], 1,
        "‘Can’ inquiries about the subject's capacity or capability (ability) to perform the task alone."),
    mcq("‘It could be a happy accident.’ Here ‘could’ denotes:",
        ["possibility", "ability", "suggestion", "request"], 0,
        "‘Could’ expresses theoretical or epistemic possibility."),
    mcq("‘------------- you join us, please?’ (formal context)",
        ["Will", "Would", "Can", "Shall"], 1,
        "‘Would’ is preferred in formal polite invitations and requests."),
    mcq("The use of ----------------- is preferred in reported speech when converting direct future statements.",
        ["Will", "Would", "Can", "Shall"], 1,
        "In backshifting for indirect speech, ‘will’ changes to its past/conditional form ‘would’."),
    mcq("‘My friend is not picking up the call. She --------- be busy.’",
        ["Could", "Would", "Shall", "Should to"], 0,
        "‘Could’ expresses plausible possibility in the present."),
]

# GA Week 6 (10 Qs)
ga_week6_qs = [
    mcq("Complete the question tag: 'He can speak many languages, ______?'",
        ["Can he", "Can’t he", "Does he", "Doesn’t he"], 1,
        "A positive statement with the modal auxiliary 'can' takes a negative tag 'can't he?'."),
    mcq("Complete the question tag: 'John likes ice cream, _____?'",
        ["Doesn’t he", "Does he", "Don’t he", "Did he"], 0,
        "Present simple affirmative with third person singular takes the tag 'doesn't he?'."),
    mcq("In the English language, which of the following does NOT participate in grammatical agreement with the verb?",
        ["Person", "Gender", "Number", "None of the above"], 1,
        "English verbs agree with their subject in person and number (e.g. 3rd person singular -s), but English verbs have no grammatical gender inflection."),
    mcq("In the sentence 'I am not sure when the incident happened', identify the main statement:",
        ["when the incident happened", "I am not sure when", "I am not sure", "the incident happened"], 2,
        "‘I am not sure’ is the matrix (main) clause containing the primary subject and verb."),
    mcq("In the sentence 'I am not sure when the incident happened', identify the embedded subordinate clause:",
        ["I am not sure", "when the incident happened", "not sure when", "the incident"], 1,
        "‘when the incident happened’ is the embedded interrogative content clause functioning as the complement."),
    mcq("Complete the sentence: '_______ you score well in the exam, I'll buy you gifts.'",
        ["Whether", "If", "Both whether and if", "Unless"], 1,
        "‘If’ introduces an open conditional clause; ‘whether’ cannot introduce a standalone conditional antecedent with 'will' in this context."),
    mcq("Identify the sentence with a finite subordinate clause:",
        [
            "We know that Sarah asks a lot of questions.",
            "He likes to sit quietly.",
            "Sarah hoped to convince John.",
            "I am glad to meet you again."
        ], 0,
        "‘that Sarah asks a lot of questions’ contains the finite verb ‘asks’ marked for present tense and 3rd person singular agreement."),
    mcq("Intransitive verbs cannot be recast in passive form.",
        ["True", "False"], 0,
        "Passive voice requires a direct object to become the grammatical subject; intransitive verbs lack objects and cannot form passive constructions."),
    mcq("Complete the sentence: 'She bought an _______ sound system.'",
        ["food", "expensive", "cheap", "expenditure"], 1,
        "The indefinite article 'an' requires a word beginning with a vowel sound, and the syntax requires an attributive adjective ('expensive')."),
    mcq("Complete the sentence: 'My cat is sleeping on the _____ roof.'",
        ["think", "thinly", "thin", "understanding"], 2,
        "The position between the article 'the' and noun 'roof' requires an attributive adjective ('thin')."),
]

# GA Week 7 (5 Qs)
ga_week7_qs = [
    mcq("Which of the following is NOT appreciated in a professional group discussion?",
        ["Polite language", "Attentiveness", "Insensitivity", "Team spirit"], 2,
        "Insensitivity undermines collaboration and respectful dialogue in a group discussion."),
    mcq("Dragging on the same points repeatedly indicates vast knowledge in the discussion area.",
        ["True", "False"], 1,
        "Reiterating the same argument wastes group time and indicates a lack of fresh perspectives or active listening."),
    mcq("Which of the following should be taken into consideration before attending an interview?",
        ["Do mock interviews", "Arrive a little early", "Research the company/institution", "All the above"], 3,
        "Comprehensive interview preparation includes institutional research, logistical punctuality, and mock rehearsals."),
    mcq("A warm smile denotes confidence and enthusiasm in the candidate.",
        ["True", "False"], 0,
        "Positive body language, including a natural smile, conveys approachable confidence and engagement."),
    mcq("The discourse marker 'To put that another way…' indicates ________.",
        ["Stating an opinion", "Expressing disagreement", "Reformulating", "Making a suggestion"], 2,
        "‘To put that another way...’ is used for reformulation or paraphrasing a concept for greater clarity."),
]

# GA Week 8 (10 Qs)
ga_week8_qs = [
    mcq("Which of the following is NOT true about writing a Statement of Purpose (SOP)?",
        ["It should be error-free", "It should not contain redundant usages", "It should be ambiguous", "It should describe specific events"], 2,
        "An SOP must be unambiguous, clear, and goal-oriented."),
    mcq("While writing an SOP, one should give evidence and concrete examples for statements about oneself.",
        ["True", "False"], 0,
        "Claims of competencies, leadership, or academic passions must be substantiated with tangible projects and achievements."),
    mcq("Creating a compelling narrative and having a defined personal angle is an important part of an SOP.",
        ["True", "False"], 0,
        "A cohesive personal narrative distinguishes an applicant from peers with similar academic metrics."),
    mcq("Use of unnecessarily complex words and convoluted sentences is one of the key criteria while writing an SOP.",
        ["True", "False"], 1,
        "Clarity, directness, and precision are valued over sesquipedalian vocabulary or convoluted sentence structure."),
    mcq("In academic writing, 'to write within limits' means:",
        ["To use fewer words", "To avoid uncommon words", "To avoid redundancy and adhere to word limits", "All the above"], 3,
        "Writing within limits involves conciseness, precision, and adherence to specified length constraints."),
    mcq("The construction 'complete dedication' in concise writing is often considered _______.",
        ["Superfluous / Pleonastic", "Ambiguous", "Archaic", "Grammatically invalid"], 0,
        "Dedication inherently implies commitment; qualifiers like 'complete' or 'total' can be redundant."),
    mcq("While writing a précis, one can make it brief by:",
        ["Removing redundant words", "Rewriting direct quotes in concise indirect speech", "Avoiding examples, illustrations, and long lists of names", "All the above"], 3,
        "A précis condenses the essential thesis by shedding peripheral examples, wordy phrasing, and parenthetical lists."),
    mcq("Coherence between sentences in a paragraph can be established through discourse markers.",
        ["True", "False"], 0,
        "Discourse markers (transitions) signal logical relationships such as addition, contrast, causation, and sequence."),
    mcq("While reading a source passage before writing a précis, one must pay attention to:",
        ["The author’s purpose, arguments, and core insights", "The main ideas of the passage", "The evidence and support for the arguments", "All the above"], 3,
        "Comprehending the overarching thesis and logical framework is required before condensing."),
    mcq("As a general guideline, a good précis is approximately one-third the length of the original passage without losing core content.",
        ["True", "False"], 0,
        "The standard target length for a précis in English academic conventions is roughly one-third of the original text."),
]

# GA Week 9 (10 unique Qs)
ga_week9_qs = [
    mcq("In the narrative, 'Dhri' appears to be whose nickname?",
        ["Draupadi’s", "Dhai Ma’s", "Dhrishtadyumna’s", "Drupad’s"], 2,
        "‘Dhri’ is the affectionate familiar nickname used for her brother Dhrishtadyumna in Chitra Banerjee Divakaruni's 'The Palace of Illusions'."),
    mcq("What is the meaning of the narrator's name (Draupadi / Panchaali)?",
        ["Light of the Universe", "Celestial Victor", "Destroyer of Enemies", "Daughter of Drupad"], 3,
        "The patronymic name signifies 'Daughter of Drupad' (King of Panchal)."),
    mcq("What is the standard meaning of the noun 'acceptability'?",
        ["Ability to like someone", "The quality of being allowed, welcomed, or tolerated", "Ability to accept everything blindly", "All of the above"], 1,
        "‘Acceptability’ refers to the state or quality of being considered acceptable, satisfactory, or tolerable."),
    mcq("Whom does the narrator consider to be stubborn and egoistic?",
        ["Her brother", "His sister", "Her father", "Their mother"], 2,
        "In the novel, Draupadi observes her father King Drupad's rigid pride and vengeful ego against Drona."),
    mcq("What is the meaning of the adjective 'celestial'?",
        ["Relating to home", "Relating to heaven or the sky", "Relating to war", "Relating to water"], 1,
        "‘Celestial’ pertains to the sky, the heavens, or divine beings."),
    mcq("In the phrase 'You have been stranded thousands of miles from home', what does 'stranded' mean?",
        ["Left in a helpless or isolated position", "Tortured", "Confused", "Imprisoned"], 0,
        "To be stranded means to be left without the means to move from somewhere or return home."),
    mcq("Fill in the blank: “Such a ___________ would make many people despair and curse their awful fate.”",
        ["Prediction", "Predicament", "Predatory", "Predecessor"], 1,
        "A ‘predicament’ is a difficult, unpleasant, or embarrassing situation."),
    mcq("In the phrase 'It became the foundation of his life’s work and legacy', what is the meaning of 'legacy'?",
        ["A set of property, values, or impact left behind after one’s departure", "A treat by a leader", "An unseen buried treasure", "A short-lived fame"], 0,
        "A ‘legacy’ denotes something transmitted by or received from an ancestor, predecessor, or past era."),
    mcq("Fill in the blank: “He _________ into a bookshop and became intrigued by reading about Socrates.”",
        ["Wanted", "Wandered", "Pondered", "Faltered"], 1,
        "‘Wandered’ means walked or strolled in a casual or leisurely way."),
    mcq("What is the meaning of the word ‘intrigued’?",
        ["Irritated", "Fascinated and curious", "Involved", "Distracted"], 1,
        "To be ‘intrigued’ means to have one's interest, wonder, or curiosity strongly aroused."),
]

# GA Week 10 (10 Qs)
ga_week10_qs = [
    mcq("‘All assignments were submitted.’ This sentence is in the passive voice.",
        ["True", "False"], 0,
        "‘were submitted’ is a passive construction (be + past participle) with an elided agent."),
    mcq("‘The displayed ornaments glittered in the dazzling lights.’ The finite verb in this sentence is:",
        ["Displayed", "Glittered", "Dazzling", "All of the above"], 1,
        "‘Glittered’ is the finite verb in past tense. ‘Displayed’ and ‘dazzling’ are participial adjectives modifying nouns."),
    mcq("In the sentence ‘The displayed ornaments glittered in the dazzling lights’, there are ___ finite verb(s) and ___ participle(s).",
        ["0, 3", "3, 0", "1, 2", "2, 1"], 2,
        "1 finite verb ('glittered') and 2 participles ('displayed' past participle, 'dazzling' present participle)."),
    mcq("Which of the following are negative-polarity sensitive elements (NPIs)?",
        ["Anyone", "Anybody", "Anything", "All of the above"], 3,
        "Indefinite pronouns with 'any-' typically occur in negative, interrogative, or conditional polarity environments."),
    mcq("‘They did not tell anyone about their plan’ is a negative sentence.",
        ["True", "False"], 0,
        "The presence of the negative particle ‘not’ makes the clause grammatically negative."),
    mcq("Choose the correct reported speech for: ‘Who did you see?’ Prema asked.",
        [
            "Prema asked me who I saw",
            "Prema asked me who I had seen",
            "Prema told me who I have seen",
            "Prema asked me who did I see"
        ], 1,
        "Past simple questions shift to past perfect in reported speech with affirmative word order: 'who I had seen'."),
    mcq("Convert to indirect speech: ‘I haven’t seen him.’",
        [
            "He said he didn’t see him",
            "He said that he hadn’t seen him",
            "He told that he didn’t see him",
            "He told that he hadn’t see him"
        ], 1,
        "Present perfect 'haven't seen' backshifts to past perfect 'hadn't seen' with the reporting verb 'said that'."),
    mcq("Complete the sentence: 'This proposal is ___ better than the previous one.'",
        ["As much", "Much", "Much of", "Not many"], 1,
        "‘Much’ functions as a degree adverb modifying comparative adjectives (much better)."),
    mcq("Complete the sentence: 'Ours is a small class. We don’t have ___ students.'",
        ["Much", "Many", "Large", "Little"], 1,
        "‘Many’ is used with plural countable nouns ('students') in negative constructions."),
    mcq("‘If they are innocent, they will be acquitted.’ This is a ___ conditional sentence.",
        ["Zero conditional", "First conditional", "Second conditional", "Mixed conditional"], 1,
        "If + present simple ('are'), will + bare infinitive ('will be acquitted') is the canonical First Conditional."),
]

# GA Week 11 (10 Qs)
ga_week11_qs = [
    mcq("‘-s’ and ‘-ies’ in ‘dogs’ and ‘babies’ are:",
        ["Plural markers", "Morphemes", "Both of the above", "None of the above"], 2,
        "They are inflectional morphemes that signify nominal plurality."),
    mcq("Reduction of a word to one of its parts without changing its meaning is called:",
        ["Blending", "Clipping", "Borrowing", "Compounding"], 1,
        "Clipping is the morphological process of shortening a word (e.g. ad from advertisement)."),
    mcq("Which of the following is an example of middle clipping?",
        ["Gym", "Flu", "Phone", "Gram"], 1,
        "‘Flu’ is clipped from both ends of ‘influenza’."),
    mcq("‘He did not break down when he heard the grave news. Rather, he became very stoic and appeared to bear it quite normally.’ The connecting discourse word is:",
        ["And", "Became", "Rather", "There is no connecting word/phrase"], 2,
        "‘Rather’ functions as an adversative/substitutive discourse connector indicating 'instead'."),
    mcq("In the context above, ‘rather’ means the same as:",
        ["Instead", "Completely", "Slowly", "Because"], 0,
        "‘Rather’ is used here to introduce an alternative course of action or demeanor."),
    mcq("Modern English contains many prefixes and suffixes borrowed from Greek and Latin.",
        ["True", "False"], 0,
        "A large portion of formal, scientific, and academic English morphology derives from classical Greek and Latin affixes."),
    mcq("‘Bungalow’, ‘loot’, and ‘pyjamas’ are English words borrowed from:",
        ["Latin", "French", "Indian languages", "Spanish"], 2,
        "These are historical loanwords originating from Hindi, Sanskrit, and Urdu during colonial interactions."),
    mcq("‘The business tycoon who made billions with his hotel chain has been found dead.’ Here, 'tycoon' means:",
        ["A headman", "A billionaire", "A CEO", "A wealthy and powerful businessperson"], 3,
        "A tycoon is an influential, wealthy person in business or industry."),
    mcq("The word 'tycoon' was borrowed into English from which language?",
        ["Latin", "French", "Italian", "Japanese"], 3,
        "‘Tycoon’ comes from the Japanese word 'taikun' (great prince/commander)."),
    mcq("‘The music club auditions allow candidates to have a karaoke to the song they’ll be singing.’ Here, 'karaoke' means:",
        ["Lyrics sheet", "Sheet music", "Pre-recorded instrumental backing track", "Acapella vocal"], 2,
        "Karaoke (from Japanese 'empty orchestra') refers to recorded backing music without the lead vocal."),
]

# GA Week 12 (10 Qs)
ga_week12_qs = [
    mcq("Choose the most professional and clear email subject line for an intra-college event:",
        [
            "Regarding intra-college quiz competition: Registration & Dates",
            "notice for students",
            "information for students",
            "Important!!"
        ], 0,
        "An effective subject line is specific, professional, and summarizes the email content."),
    mcq("Choose the most appropriate salutation when writing a formal email to a group of university peers:",
        ["Hey friends", "Dear All / Hello everyone", "Howdy folks", "Yo team"], 1,
        "‘Dear All’ or ‘Hello everyone’ is respectful, inclusive, and professional."),
    mcq("Choose the most appropriate professional sign-off title for a course representative in official correspondence:",
        ["Student Representative", "Student Officer", "Student Bro", "Campus VIP"], 0,
        "‘Student Representative’ clearly communicates the sender's official role to faculty and peers."),
    mcq("If the specific recipient is unknown, what is the standard professional salutation in formal correspondence?",
        ["Dear Sir/Madam", "Hey", "Hello buddy", "To the guy in charge"], 0,
        "‘Dear Sir/Madam’ or ‘Dear Hiring Team / Committee’ is standard when the recipient's name is not available."),
    mcq("If you are advancing a thesis, presenting claims, and countering opposing views, what kind of research report are you writing?",
        ["Analytical", "Expository", "Argumentative", "Descriptive"], 2,
        "An argumentative report evaluates divergent perspectives and defends a justified conclusion with reasoned premises."),
    mcq("In sociolinguistics and communication models, what are the forms and styles of speech (written vs. spoken, dialect) called?",
        ["Barriers", "Instrumentalities", "Scene writing", "Stage setting"], 1,
        "In Dell Hymes's SPEAKING model, 'I' stands for Instrumentalities (channels, registers, and styles of speech)."),
    mcq("In Dell Hymes's acronym SPEAKING model of communication, what does the letter 'A' refer to?",
        ["Act sequence", "Arbitration", "Acceptance of the audience", "Appraisal"], 0,
        "In the SPEAKING model: S = Setting, P = Participants, E = Ends, A = Act sequence (form and order of events)."),
    mcq("Organizational hierarchy leading to communication breakdown is classified as a/an:",
        ["Organisational barrier", "Physical/Mechanical barrier", "Language/Semantic barrier", "Personal barrier"], 0,
        "Rigid departmental stratification and bureaucratic layers represent organizational barriers to open communication."),
    mcq("Which of the following are common psychological and behavioral challenges during an interview?",
        ["Anxiety and stress", "Inadequate preparation", "Frequent distractions", "All of the above"], 3,
        "Interview performance is commonly impaired by cognitive anxiety, lack of preparation, and attentional distractions."),
    mcq("Faulty translation or misinterpretation of technical jargon is classified as a/an:",
        ["Organisational barrier", "Physical/Mechanical barrier", "Language / Semantic barrier", "Environmental barrier"], 2,
        "Semantic barriers arise from misunderstandings of symbols, vocabulary, translation differences, or jargon."),
]


# ==============================================================================
# PRACTICE ASSIGNMENTS (PA WEEKS 1 - 12)
# ==============================================================================

# PA Week 1 (9 Qs)
pa_week1_qs = [
    mcq("“It was the best of times, it was the worst of times.” The figure of speech used here is:",
        ["Paradox", "Oxymoron", "Irony", "Antithesis"], 3,
        "Antithesis brings contrasting ideas together in balanced grammatical structures."),
    mcq("“To be or not to be, that is the question” is an example of an oxymoron.",
        ["True", "False"], 1,
        "It is a classic example of antithesis (balanced juxtaposition of opposing concepts), not an oxymoron."),
    mcq("“Sit down awhile; / And let us once again assail your ears, / That are so fortified against our story / What we have two nights seen.” What poetic/rhetorical device is prominent in 'assail your ears'?",
        ["Metaphor", "Oxymoron", "Hyperbole", "Euphemism"], 0,
        "‘Assail your ears’ is a vivid metaphor treating speech as an assault on the senses."),
    mcq("“Denial ain’t just a river in Egypt” is an example of a/an:",
        ["Paradox", "Oxymoron", "Pun", "Irony"], 2,
        "This is a well-known pun playing on the phonetic similarity between 'denial' and 'the Nile'."),
    mcq("Choose the word that best expresses exactitude: 'This is ___ what I meant!'",
        ["Truly", "Exactly", "Something", "Barely"], 1,
        "‘Exactly’ is the standard adverb specifying total precision."),
    mcq("Choose the appropriate exclamation: '____, this place looks amazing!'",
        ["Wow", "Rather", "Which", "Despite"], 0,
        "‘Wow’ is an emotive interjection expressing admiration or surprise."),
    mcq("The relative pronoun 'which' can be used as a connective discourse marker to provide supplementary comment on a whole clause.",
        ["True", "False"], 0,
        "Sentential relative clauses introduced by 'which' serve as cohesive discourse devices adding evaluative comments."),
    mcq("Which of the following discourse markers can be used to resume a theme after an interruption or change in subject?",
        ["Apparently", "As I was saying / As I said", "In addition", "Consequently"], 1,
        "‘As I was saying’ or ‘As I said’ explicitly signals a return to a previously established topic."),
    mcq("In written English, pitch accents, emphatic stress, or intonational salience are conventionally indicated with:",
        ["Italics or quotation marks", "Semicolons", "Apostrophes", "Ampersands"], 0,
        "Typography uses italics, boldface, or inverted commas to signal vocal stress and tone in text."),
]

# PA Week 2 (9 Qs)
pa_week2_qs = [
    mcq("Adverbs of time answer which of the following questions?",
        ["How often", "When", "Where", "Why"], 1,
        "Adverbs of time specify temporal location ('When?')."),
    mcq("In the sentence 'She checked the document thoroughly', 'thoroughly' is an adverb of:",
        ["Direction", "Manner / Degree", "Place", "Time"], 1,
        "‘Thoroughly’ describes the manner and completeness (degree) of the action."),
    mcq("Adverbs of degree answer which question?",
        ["What", "Why", "Where", "How much / To what extent"], 3,
        "Adverbs of degree quantify intensity or extent ('How much?')."),
    mcq("‘In four years, I will have finished college and obtained my degree.’ This sentence is in the:",
        ["Future Indefinite", "Future Continuous", "Future Perfect", "Future Perfect Continuous"], 2,
        "‘will have finished’ is the future perfect tense (will + have + past participle)."),
    mcq("The passive form of ‘They had already informed Sarah’ is:",
        ["Sarah has already been informed", "Sarah have already been informed", "Sarah had already been informed", "Sarah had already informed them"], 2,
        "Past perfect active ‘had informed’ becomes past perfect passive ‘had been informed’."),
    mcq("In which of the following sentences is an attributive adjective used with a degree adverb?",
        ["She was extremely happy.", "She had an absolutely wonderful day.", "She was very confused.", "The house is quite large."], 1,
        "‘wonderful’ is an attributive adjective preceding the noun ‘day’, modified by the degree adverb ‘absolutely’."),
    mcq("Complete the sentence: ‘Ruth _______ has no idea as to what is happening.’",
        ["Clearly", "Obviously", "Both (a) and (b)", "None of the above"], 2,
        "Both ‘clearly’ and ‘obviously’ function as comment adverbs modifying the entire clause."),
    mcq("‘Apparently, you have to submit the forms both as soft copies and as hard copies.’ This sentence uses a comment adverb indicating:",
        ["Moral judgement", "Emotional reaction", "Evidentiality / Perceived likelihood", "Temporal sequence"], 2,
        "‘Apparently’ is an evidential comment adverb indicating information based on hearsay or outward appearance."),
    mcq("In ‘The soup was too hot to drink’, the adverb ‘too’ denotes:",
        ["There was enough heat", "Additional heat", "An excess beyond what is desirable or acceptable", "A pleasant degree of heat"], 2,
        "‘Too’ before an adjective indicates an excessive, undesirable degree."),
]

# PA Week 3 (8 Qs: 4 original + 4 syllabus-aligned)
pa_week3_qs = [
    mcq("‘Fatima takes the bus to go to work.’ is a simple sentence.",
        ["True", "False"], 0,
        "It consists of one main clause with a non-finite infinitive of purpose."),
    mcq("‘Joe buys a cup of coffee from the canteen everyday.’ This sentence has:",
        ["1 clause", "2 clauses", "3 clauses", "4 clauses"], 0,
        "There is only one finite verb phrase ('buys') with its subject and adjuncts, making it 1 clause."),
    mcq("‘The hall of archives is a huge place.’ In this sentence, the subject complement is:",
        ["The hall", "Of archives", "Is a huge place", "A huge place"], 3,
        "‘A huge place’ is the noun phrase acting as a subject complement following the linking verb ‘is’."),
    mcq("‘The hall of archives is a huge place.’ In this sentence, there are:",
        ["No adjuncts", "Two adjuncts", "One adverbial adjunct", "Three adjuncts"], 0,
        "The sentence follows the SVC pattern (Subject: 'The hall of archives', Verb: 'is', Complement: 'a huge place') with no adjuncts."),
    mcq("In the sentence ‘The committee elected Dr. Sharma chairperson’, ‘chairperson’ functions as a/an:",
        ["Subject complement", "Object complement", "Direct object", "Adjunct"], 1,
        "‘chairperson’ describes the result/attribute of the direct object ‘Dr. Sharma’ (Object complement)."),
    mcq("Which of the following sentences follows the SVOC (Subject - Verb - Object - Complement) pattern?",
        ["She found the examination difficult.", "He gave her a valuable present.", "They arrived late in the evening.", "The train stopped suddenly."], 0,
        "Subject: She, Verb: found, Object: the examination, Complement: difficult."),
    mcq("In ‘They live in Bangalore’, ‘in Bangalore’ is an obligatory adverbial complement of the verb ‘live’.",
        ["True", "False"], 0,
        "The intransitive verb 'live' (in the sense of reside) requires a locative complement for syntactic completeness."),
    mcq("Identify the sentence with an indirect object:",
        ["The professor explained the theorem clearly.", "She offered him a cup of tea.", "The team played exceptionally well.", "The meeting ended at noon."], 1,
        "‘him’ is the indirect object receiving the direct object ‘a cup of tea’."),
]

# PA Week 4 (6 Qs: Academic Essay Writing & Argumentation)
pa_week4_qs = [
    mcq("The introductory paragraph of an academic essay should contain which key element?",
        ["A thesis statement", "A comprehensive list of references", "A conclusion", "All detailed data tables"], 0,
        "The thesis statement introduces the core claim or central argument of the entire essay."),
    mcq("In academic writing, topic sentences are typically placed at:",
        ["The middle of every paragraph", "The beginning of body paragraphs to establish the main focus", "The end of the bibliography", "Only in the title"], 1,
        "A topic sentence introduces the controlling idea of that specific paragraph."),
    mcq("What is the primary function of transitional discourse markers (e.g. 'furthermore', 'on the other hand') in essay writing?",
        ["To pad the word count", "To establish smooth logical transitions between ideas and paragraphs", "To replace verbs", "To eliminate punctuation"], 1,
        "Transitions guide the reader through the logical progression and contrasts of an argument."),
    mcq("A well-constructed academic conclusion should simply repeat the introduction word for word.",
        ["True", "False"], 1,
        "A conclusion should synthesize the main arguments and provide broader implications, not merely repeat earlier text verbatim."),
    mcq("Which of the following is considered poor practice in academic essay writing?",
        ["Using evidence from peer-reviewed sources", "Incorporating counter-arguments and addressing them", "Making sweeping generalizations without empirical support", "Maintaining third-person formal register"], 2,
        "Unsupported sweeping generalizations undermine the academic rigor and credibility of an essay."),
    mcq("In an argumentative essay, what is the purpose of addressing counter-arguments (rebuttals)?",
        ["To confuse the reader", "To demonstrate nuanced understanding and strengthen the author's own thesis", "To shorten the essay", "To avoid reaching a conclusion"], 1,
        "Acknowledging and refuting opposing perspectives demonstrates critical evaluation and bolsters the primary argument."),
]

# PA Week 5 (8 Qs)
pa_week5_qs = [
    mcq("‘It sounds like the rain might be stopping.’ The modal verb in this sentence is:",
        ["Be", "Might", "Like", "Sounds"], 1,
        "‘Might’ is the modal auxiliary expressing possibility."),
    mcq("Complete the sentence expressing past possibility: ‘She _____ have won the championship if she had not injured her ankle.’",
        ["Can", "Could", "Ought", "Shall"], 1,
        "‘Could have + past participle’ expresses unfulfilled past possibility or ability."),
    mcq("‘I will read you the text message she sent when we meet tomorrow.’ The tense/modal auxiliary indicating future reference is:",
        ["Will", "Read", "Meet", "Sent"], 0,
        "‘Will’ functions as the auxiliary verb indicating future tense."),
    mcq("Unlike lexical verbs which describe states or actions, modal auxiliaries fundamentally express:",
        ["Factual descriptions of real-world objects", "Speaker attitude towards factuality (possibility, obligation, permission)", "Physical movement", "Direct objects"], 1,
        "Modality expresses speaker stance on possibility, necessity, permission, or intention rather than asserting facts."),
    mcq("In English linguistics, 'will' and 'shall' are modal auxiliaries that also function to mark future reference.",
        ["True", "False"], 0,
        "English lacks an inflectional future tense; future time is primarily realized via modal auxiliaries like 'will' and 'shall'."),
    mcq("‘Lata ______ decide upon her summer plans as soon as possible so that she is able to book tickets before they sell out.’",
        ["Should", "Must", "Ought to", "All of the above"], 3,
        "Depending on the degree of urgency, all three modals can grammatically express necessity or strong advice."),
    mcq("Which among the following is NOT a modal verb?",
        ["Can", "Could", "Is", "May"], 2,
        "‘Is’ is a primary auxiliary / copula verb, not a modal auxiliary."),
    mcq("‘Back then, no one _______ challenge him. He was very good at boxing.’",
        ["Can", "Could", "May", "Shall"], 1,
        "‘Could’ expresses general ability in the past."),
]

# PA Week 6 (10 Qs)
pa_week6_qs = [
    mcq("Convert the statement ‘She listens to music everyday’ into a present simple question:",
        [
            "Did she listens to music everyday?",
            "Did she listen to music everyday?",
            "Does she listens to music everyday?",
            "Does she listen to music everyday?"
        ], 3,
        "Present simple with third person singular uses auxiliary 'Does' + bare infinitive 'listen'."),
    mcq("Convert the statement ‘He has finished his homework’ into an interrogative sentence:",
        [
            "Did he finished his homework?",
            "Has he finish his homework?",
            "Has he finished his homework?",
            "Did he finish his homework?"
        ], 2,
        "Inversion of the auxiliary 'has' with the subject produces: 'Has he finished his homework?'."),
    mcq("Which of the following is a polite indirect embedded question for ‘Is he a businessman?’",
        [
            "Do you know if he is a businessman?",
            "Do you know if he was a businessman?",
            "Tell me is he a businessman?",
            "Who is he a businessman?"
        ], 0,
        "Embedded yes/no questions use 'if' or 'whether' with declarative word order."),
    mcq("Embedded questions are commonly used in English to:",
        ["Sound more polite and less blunt", "Inquire about indirect information", "Form indirect speech", "All the above"], 3,
        "Embedding question clauses softens direct inquiries, enhances politeness, and facilitates reported inquiry."),
    mcq("Complete the sentence: ‘I am worried about ______ the presentation was well received.’",
        ["Whether", "If", "Both whether and if", "That"], 0,
        "After prepositions (like 'about'), 'whether' is required in standard English; 'if' cannot directly follow a preposition."),
    mcq("Complete the sentence: ‘I am unsure _______ I will be attending the annual function.’",
        ["Whether", "If", "Both whether and if", "Unless"], 2,
        "Both 'whether' and 'if' can introduce the embedded complement clause after an adjective like 'unsure'."),
    mcq("In the sentence ‘I am unsure whether I will be attending the function’, the embedded clause is a/an:",
        ["Non-finite clause", "Finite clause", "Verbless clause", "Independent sentence"], 1,
        "The clause contains the finite auxiliary verb ‘will’, making it a finite clause."),
    mcq("In the sentence ‘I am unsure whether I will be attending the function’, the embedded clause functions as the ______ of the predicate adjective ‘unsure’.",
        ["Subject", "Complement", "Adjunct of manner", "Direct object of a noun"], 1,
        "The clause completes the meaning of the adjective 'unsure' (adjectival complement)."),
    mcq("In the sentence ‘They want to see what all the fuss is about’, the clause ‘what all the fuss is about’ is the direct object of the verb:",
        ["Is", "See", "Want", "Not an object"], 1,
        "‘Want’ takes the non-finite clause ‘to see...’ as its object, and ‘see’ takes the interrogative clause ‘what all the fuss is about’ as its object."),
    mcq("The question ‘When did she return from Germany?’ is what type of question?",
        ["Wh- / Content question", "Yes/no question", "Tag question", "Rhetorical question without answer"], 0,
        "Questions introduced by question words (when, where, why, who) seek specific information (content/Wh- questions)."),
]

# PA Week 7 (6 Qs: Interviews & Group Discussions)
pa_week7_qs = [
    mcq("In a group discussion, what is the best strategy when you disagree with another participant?",
        [
            "Interrupt them immediately and state they are wrong",
            "Politely acknowledge their perspective and state your counter-point with evidence",
            "Remain silent and refuse to participate further",
            "Mock their argument"
        ], 1,
        "Constructive disagreement begins with respectful acknowledgement followed by clear evidence."),
    mcq("What does active listening in an interview or group discussion entail?",
        [
            "Focusing solely on what you plan to say next",
            "Maintaining eye contact, nodding, and synthesizing points made by others",
            "Looking out the window",
            "Speaking continuously without pausing"
        ], 1,
        "Active listening demonstrates engagement through positive non-verbal cues and cohesive contributions."),
    mcq("The acronym STAR in competency-based interviews stands for:",
        [
            "Situation, Task, Action, Result",
            "Strategy, Technique, Approach, Response",
            "Subject, Theme, Argument, Reference",
            "Speaking, Tone, Attitude, Rapport"
        ], 0,
        "STAR technique structure: Situation (context), Task (challenge), Action (steps taken), Result (outcome)."),
    mcq("In a group discussion, taking the initiative to initiate the discussion without knowing the topic is always advantageous.",
        ["True", "False"], 1,
        "Initiating without substance or clarity can backfire; contributing meaningful, structured points is far more valuable."),
    mcq("Which of the following phrases is most appropriate for politely entering an ongoing group discussion?",
        [
            "Shut up, let me speak",
            "May I add a quick point to what was just discussed?",
            "You are all talking nonsense",
            "Hey, listen to me"
        ], 1,
        "‘May I add a point...’ allows a smooth, polite intervention into the conversational floor."),
    mcq("Non-verbal communication such as posture, nodding, and eye contact accounts for a significant portion of an interviewer's impression.",
        ["True", "False"], 0,
        "Kinesics and non-verbal cues strongly reinforce spoken professional credibility and confidence."),
]

# PA Week 8 (8 Qs: 4 original + 4 syllabus-aligned on Précis Writing)
pa_week8_qs = [
    mcq("In concise writing, a 'simple word' typically means a:",
        [
            "Monosyllabic word",
            "Polysyllabic word",
            "Monosyllabic or disyllabic word with clear, well-known meaning",
            "Rare jargon term"
        ], 2,
        "Clear writing favors widely understood short words over obscure multi-syllable terms."),
    mcq("In précis writing, numbers should always be spelled out in words rather than using digits to maintain style.",
        ["True", "False"], 1,
        "Standard practice is to use Arabic numerals for complex numbers to maintain brevity and clarity."),
    mcq("Which of the following principles must be maintained while writing a précis?",
        [
            "Be clear and concise",
            "Maintain coherence and logical flow",
            "Capture only the essential core arguments without extraneous examples",
            "All of the above"
        ], 3,
        "A précis demands brevity, structural clarity, coherence, and fidelity to the author's primary thesis."),
    mcq("Précis writing is identical to paraphrasing a passage.",
        ["True", "False"], 1,
        "Paraphrasing restates text with similar length, whereas a précis significantly condenses it to approximately one-third."),
    mcq("A précis writer should introduce personal opinions, outside knowledge, and criticism into the summary.",
        ["True", "False"], 1,
        "A précis must strictly reflect the ideas in the source passage without external commentary or personal opinion."),
    mcq("A good précis should always be written in the writer's own words rather than copying whole sentences from the original.",
        ["True", "False"], 0,
        "Expressing source ideas in fresh, concise syntax is fundamental to genuine précis writing."),
    mcq("What should be omitted when drafting a précis?",
        [
            "The author's core thesis",
            "Illustrative anecdotes, digressions, and redundant adjectives",
            "The main conclusion",
            "Logical linking words"
        ], 1,
        "Illustrative examples, rhetorical digressions, and repetitive descriptors should be pruned."),
    mcq("Which grammatical tense and point of view is conventionally preferred when writing a précis of a speech or narrative?",
        [
            "First person ('I believe...') in the future tense",
            "Third person in reported past/present speech",
            "Second person imperative",
            "Passive voice exclusively"
        ], 1,
        "Précis writing typically adopts an objective third-person perspective."),
]

# PA Week 9 (8 Qs: 4 original + 4 on Arundhati Roy's text)
ROY_CONTEXT = (
    "Context: Read the excerpt from Arundhati Roy's 'The God of Small Things':\n\n"
    "\"May in Ayemenem is a hot, brooding month. The days are long and humid. The river shrinks and "
    "black crows gorge on bright mangoes in still, dustgreen trees. But by June the southwest monsoon "
    "breaks and there are three months of wind and water with short lulls of sharp, glittering sunshine. "
    "It is a time when the countryside turns an immodest green... The rain slanted down like silver ropes, "
    "crashing onto the corrugated tin roofs like gunfire. It was during this tempestuous season that Rahel "
    "returned to Ayemenem after twenty-three long years to see her twin brother Esthappen...\""
)

pa_week9_qs = [
    mcq("According to the passage, during which month did the southwest monsoon break when Rahel returned to Ayemenem?",
        ["May", "June", "December", "April"], 1,
        "The passage states: 'by June the southwest monsoon breaks... It was during this tempestuous season that Rahel returned'.", context=ROY_CONTEXT),
    mcq("In the passage, the author vividly compares the falling rain to:",
        ["Silver ropes and gunfire", "Bright fireworks", "Whispering leaves", "Flying insects"], 0,
        "The text uses the similes: 'slanted down like silver ropes, crashing onto the corrugated tin roofs like gunfire'.", context=ROY_CONTEXT),
    mcq("What is the primary emotional purpose of Rahel’s return to Ayemenem?",
        [
            "To buy property",
            "To visit her twin brother Estha after years of separation",
            "To escape the summer heat",
            "To visit a corporate office"
        ], 1,
        "Rahel returns after twenty-three years to reunite with her twin brother Estha.", context=ROY_CONTEXT),
    mcq("What does the word ‘bluebottles’ refer to in descriptive nature writing?",
        ["Bottles painted blue", "A type of blowfly / insect", "A kind of vehicle", "A medicinal syrup"], 1,
        "Bluebottles are large blowflies with an iridescent metallic blue body common in humid environments.", context=ROY_CONTEXT),
    mcq("What figurative device is used in the phrase 'the countryside turns an immodest green'?",
        ["Personification", "Onomatopoeia", "Hyperbole", "Synecdoche"], 0,
        "Attributing the human trait of modesty ('immodest') to nature is personification.", context=ROY_CONTEXT),
    mcq("The sensory imagery describing crows gorging on bright mangoes appeals to which senses?",
        ["Visual and kinetic imagery", "Olfactory exclusively", "Auditory exclusively", "Tactile exclusively"], 0,
        "Bright mangoes, black crows, and dustgreen trees create vivid visual and kinetic imagery.", context=ROY_CONTEXT),
    mcq("In the phrase 'hot, brooding month', the word 'brooding' conveys a mood of:",
        ["Lighthearted festivity", "Ominous, heavy, and contemplative tension", "Carefree joy", "Frigid detachment"], 1,
        "‘Brooding’ conveys a sultry, oppressive, emotionally charged atmosphere preceding the tempest."),
    mcq("Which word from the passage means 'a temporary period of calm or quiet'?",
        ["Tempestuous", "Lull", "Immodest", "Gorge"], 1,
        "A ‘lull’ is a brief interval of calm or lessened activity during a storm."),
]

# PA Week 10 (9 Qs)
pa_week10_qs = [
    mcq("‘He makes a living by teaching.’ In this sentence:",
        [
            "‘Teaching’ is a gerund; ‘by teaching’ is an adjunct prepositional phrase; ‘living’ functions as a noun.",
            "‘Teaching’ is a finite verb.",
            "‘Living’ is the finite verb in past tense.",
            "There are no non-finite forms."
        ], 0,
        "‘Teaching’ is the non-finite gerund object of the preposition ‘by’; ‘a living’ is a nominal object."),
    mcq("In the sentence ‘The displayed ornaments glittered in the dazzling lights’, count the finite verbs and participles:",
        ["1 finite verb, 2 participles", "0 finite verbs, 3 participles", "3 finite verbs, 0 participles", "2 finite verbs, 1 participle"], 0,
        "1 finite verb ('glittered') and 2 participles ('displayed', 'dazzling')."),
    mcq("‘The table legs will not give way under such a heavy load of books.’ In this negative sentence, the tense auxiliary and the negation are separate words.",
        ["True", "False"], 0,
        "The modal tense marker 'will' and the negative particle 'not' are distinct words."),
    mcq("In the construction ‘will not give way’, the negative particle ‘not’ appears between the auxiliary and the lexical verb.",
        ["True", "False"], 0,
        "Standard English clausal negation places 'not' directly after the first auxiliary verb and before the lexical verb."),
    mcq("‘Did anyone see my scarf?’ is a grammatically negative sentence.",
        ["True", "False"], 1,
        "It is an interrogative sentence containing an NPI ('anyone'), but it contains no grammatical negation ('not')."),
    mcq("A reported clause in indirect speech (e.g. 'She said that she was leaving') is a/an:",
        ["Independent clause", "Dependent / Subordinate clause", "Coordinate main clause", "Parenthetical expletive"], 1,
        "The reported clause is an embedded dependent content clause serving as the object of the reporting verb."),
    mcq("Quantifiers can be used to quantify finite verbs in large quantities (e.g. *'She many walked').",
        ["True", "False"], 1,
        "Quantifiers modify nominals or noun phrases, not verbs; verbs are modified by adverbs."),
    mcq("Complete the sentence: ‘There are ____ suppliers in the market.’",
        ["Many", "Too many", "Both (a) and (b)", "Much"], 2,
        "Both 'many' and 'too many' can grammatically modify plural countable nouns ('suppliers')."),
    mcq("‘They will get the slots if they pay upfront.’ This is an example of a:",
        ["Zero conditional", "First conditional", "Second conditional", "Third conditional"], 1,
        "If + present simple ('pay'), will + base verb ('will get') is a canonical First Conditional sentence."),
]

# PA Week 11 (9 Qs)
pa_week11_qs = [
    mcq("Reduction of a longer word to one of its parts (e.g. 'dorm' from 'dormitory') is called:",
        ["Blending", "Clipping", "Borrowing", "Back-formation"], 1,
        "Clipping shortens a polysyllabic word without altering its grammatical category or core meaning."),
    mcq("‘He has been unhappy since his cat disappeared.’ How many derivational prefixes are present in the italicized words?",
        ["1", "2 (un- in unhappy, dis- in disappeared)", "3", "4"], 1,
        "The negative prefix 'un-' in 'unhappy' and the reversative prefix 'dis-' in 'disappeared' total 2 prefixes."),
    mcq("Pick the odd one out among the following words: 'Though, eventually, is, but'",
        ["Though", "Eventually", "Is", "But"], 2,
        "‘Is’ is a finite copular verb, whereas 'though', 'eventually', and 'but' are discourse markers / conjunctions / adverbs."),
    mcq("Which of the following is a set of words popularized through internet culture and digital media?",
        [
            "Browse, collect, mend",
            "Browse, surf, scroll",
            "Cycle, steer, brake",
            "Harvest, plow, sow"
        ], 1,
        "‘Browse’, ‘surf’, and ‘scroll’ took on widely recognized computing and web navigation senses."),
    mcq("‘Chic’, ‘sentiment’, and ‘royal’ are English words borrowed historically from:",
        ["Indian languages", "Celtic", "Italian", "French"], 3,
        "These words entered English from Old French and Anglo-Norman."),
    mcq("‘The movie plot was so cliché: boy loves girl, girl loves best friend.’ Here, 'cliché' means:",
        ["Overused, stereotyped, and lacking originality", "Boring and soporific", "Melancholy and tragic", "Inspirational and fresh"], 0,
        "A cliché is an expression or idea that has been overused to the point of losing its original novelty."),
    mcq("The word 'cliché' was borrowed into English from which language?",
        ["Latin", "French", "Italian", "German"], 1,
        "‘Cliché’ is a direct loanword from French (originally a printing term for a stereotype plate)."),
    mcq("‘The bullet ricocheted off the concrete wall.’ Here, 'ricocheted' means:",
        ["Buried deep", "Rebounded or bounced off a surface at an angle", "Exploded into fragments", "Melted"], 1,
        "To ricochet means to bounce off a surface with glancing deflection."),
    mcq("The word 'ricochet' is of which linguistic origin?",
        ["French", "Latin", "Italian", "Japanese"], 0,
        "‘Ricochet’ entered English from French."),
]

# PA Week 12 (9 Qs)
pa_week12_qs = [
    mcq("In formal business email correspondence, what is the standard professional salutation when addressing a recipient with an academic or professional title?",
        [
            "Title + First name only (e.g. Dr. John)",
            "Title + Surname (e.g. Dr. Smith)",
            "Title + First name + Surname (e.g. Dr. John Smith)",
            "Both (b) and (c) are acceptable in formal English"
        ], 3,
        "Using Title + Surname or Title + Full Name is standard in polite professional correspondence."),
    mcq("Which of the following salutations is acceptable when sending an informal email to a close friend or peer?",
        ["Hey", "Hi", "Dear", "All the above depending on the interpersonal closeness"], 3,
        "Informal communications permit various casual greetings depending on relationship closeness."),
    mcq("Choose the most professional closing inquiry line from the following:",
        [
            "I look forward to hearing from you at your earliest convenience.",
            "What is the cost of your services?",
            "Reply quickly bro",
            "Bye for now"
        ], 0,
        "‘I look forward to hearing from you...’ is an established, polite professional closing line."),
    mcq("What is the single sentence that concisely encapsulates the central claim or main focus of a research report called?",
        ["Introduction", "Literature review", "Thesis statement", "Abstract footer"], 2,
        "The thesis statement summarizes the central proposition and roadmap of a research document."),
    mcq("In communication ethnography, what term refers to the physical time and place of a communicative event?",
        ["Scene", "Setting", "Act sequence", "Key"], 1,
        "‘Setting’ denotes the physical time, space, and environmental circumstances of a communicative act."),
    mcq("During a public presentation or formal speech, addressees and listeners constitute the:",
        ["Audience / Participants", "Cast", "Crew", "Interpreters"], 0,
        "In the SPEAKING model, 'P' refers to Participants, specifically the speaker and audience/hearers."),
    mcq("In Dell Hymes's SPEAKING model, what does the letter 'K' stand for?",
        ["Knowledge", "Key (tone, manner, or spirit of the act)", "Kinship", "Keystroke"], 1,
        "‘Key’ refers to the tone, manner, or spirit (e.g. formal, playful, solemn) of the communicative act."),
    mcq("External environmental noise that prevents clear hearing of a speaker is classified as a:",
        ["Organisational barrier", "Physical / Mechanical barrier", "Semantic barrier", "Personal barrier"], 1,
        "Acoustic noise, distance, and faulty audio equipment are physical or environmental barriers."),
    mcq("Which of the following are constructive steps to take when preparing for a high-stakes job interview?",
        [
            "Organise structured information about your experiences and achievements",
            "Research the organization's culture, mission, and current projects",
            "Prepare your documents and review common behavioral questions",
            "All of the above"
        ], 3,
        "Thorough interview preparation synthesizes personal evidence, company knowledge, and document readiness."),
]

def main():
    print("Generating all 24 verified English 2 assignment papers...\n")
    
    # 12 Graded Assignments
    gas = [
        ("English 2 · Graded Assignment · Week 1", 1, ga_week1_qs, "English_2_-_Graded_Assignment_-_Week_1.json"),
        ("English 2 · Graded Assignment · Week 2", 2, ga_week2_qs, "English_2_-_Graded_Assignment_-_Week_2.json"),
        ("English 2 · Graded Assignment · Week 3", 3, ga_week3_qs, "English_2_-_Graded_Assignment_-_Week_3.json"),
        ("English 2 · Graded Assignment · Week 4", 4, ga_week4_qs, "English_2_-_Graded_Assignment_-_Week_4.json"),
        ("English 2 · Graded Assignment · Week 5", 5, ga_week5_qs, "English_2_-_Graded_Assignment_-_Week_5.json"),
        ("English 2 · Graded Assignment · Week 6", 6, ga_week6_qs, "English_2_-_Graded_Assignment_-_Week_6.json"),
        ("English 2 · Graded Assignment · Week 7", 7, ga_week7_qs, "English_2_-_Graded_Assignment_-_Week_7.json"),
        ("English 2 · Graded Assignment · Week 8", 8, ga_week8_qs, "English_2_-_Graded_Assignment_-_Week_8.json"),
        ("English 2 · Graded Assignment · Week 9", 9, ga_week9_qs, "English_2_-_Graded_Assignment_-_Week_9.json"),
        ("English 2 · Graded Assignment · Week 10", 10, ga_week10_qs, "English_2_-_Graded_Assignment_-_Week_10.json"),
        ("English 2 · Graded Assignment · Week 11", 11, ga_week11_qs, "English_2_-_Graded_Assignment_-_Week_11.json"),
        ("English 2 · Graded Assignment · Week 12", 12, ga_week12_qs, "English_2_-_Graded_Assignment_-_Week_12.json"),
    ]
    for title, wk, qs, fname in gas:
        save_quiz(title, "practice_graded", wk, qs, fname)

    # 12 Practice Assignments
    pas = [
        ("English 2 · Practice Assignment · Week 1", 1, pa_week1_qs, "English_2_-_Practice_Assignment_-_Week_1.json"),
        ("English 2 · Practice Assignment · Week 2", 2, pa_week2_qs, "English_2_-_Practice_Assignment_-_Week_2.json"),
        ("English 2 · Practice Assignment · Week 3", 3, pa_week3_qs, "English_2_-_Practice_Assignment_-_Week_3.json"),
        ("English 2 · Practice Assignment · Week 4", 4, pa_week4_qs, "English_2_-_Practice_Assignment_-_Week_4.json"),
        ("English 2 · Practice Assignment · Week 5", 5, pa_week5_qs, "English_2_-_Practice_Assignment_-_Week_5.json"),
        ("English 2 · Practice Assignment · Week 6", 6, pa_week6_qs, "English_2_-_Practice_Assignment_-_Week_6.json"),
        ("English 2 · Practice Assignment · Week 7", 7, pa_week7_qs, "English_2_-_Practice_Assignment_-_Week_7.json"),
        ("English 2 · Practice Assignment · Week 8", 8, pa_week8_qs, "English_2_-_Practice_Assignment_-_Week_8.json"),
        ("English 2 · Practice Assignment · Week 9", 9, pa_week9_qs, "English_2_-_Practice_Assignment_-_Week_9.json"),
        ("English 2 · Practice Assignment · Week 10", 10, pa_week10_qs, "English_2_-_Practice_Assignment_-_Week_10.json"),
        ("English 2 · Practice Assignment · Week 11", 11, pa_week11_qs, "English_2_-_Practice_Assignment_-_Week_11.json"),
        ("English 2 · Practice Assignment · Week 12", 12, pa_week12_qs, "English_2_-_Practice_Assignment_-_Week_12.json"),
    ]
    for title, wk, qs, fname in pas:
        save_quiz(title, "practice", wk, qs, fname)

    print("\nGeneration complete!")

if __name__ == "__main__":
    main()
