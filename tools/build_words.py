#!/usr/bin/env python3
"""Builds Wordfall/Resources/words.json, the bundled word database.

Requires: pip install wordfreq english-words better_profanity

Every entry is a word the game accepts as an answer. Entries marked
"playable" are also eligible to be chosen as a falling word. Answers are
accepted by anagram signature, so the accepted set is deliberately larger
than the playable set (e.g. OPTS is accepted for STOP but never spawned).
"""
import json
import pathlib
import re

from better_profanity import profanity
from english_words import get_english_words_set
from wordfreq import top_n_list, zipf_frequency

MIN_LEN, MAX_LEN = 3, 9
ACCEPT_ZIPF = 2.3      # rarer words are not accepted as answers
PLAYABLE_ZIPF = 3.5    # rarer words are never spawned
COMMON_ZIPF = 4.0
RARE_LETTERS = set("jqxzvkw")

web2 = get_english_words_set(["web2"], lower=False, alpha=True)
gcide = get_english_words_set(["gcide"], lower=False, alpha=True)
lower_dict = {w for w in web2 | gcide if w.islower()}
# Playable words must be in both dictionaries, which filters out most names,
# abbreviations and archaic spellings that slip through one of them.
strict_dict = {w for w in web2 if w.islower()} & {w.lower() for w in gcide}
capitalized = {w.lower() for w in web2 | gcide if w[:1].isupper()}

profanity.load_censor_words()
BLOCK = {str(w) for w in profanity.CENSOR_WORDSET}
EXTRA_BLOCK = {
    "nazi", "nazis", "rape", "raped", "rapes", "rapist", "slave", "slaves",
    "negro", "negroes", "kill", "kills", "killed", "suicide", "porn", "sex",
    "sexy", "nude", "nudes", "drug", "drugs", "heroin", "cocaine", "gay",
    "lesbian", "jew", "jews", "homo", "fag", "dyke", "tits", "boob", "boobs",
    "penis", "vagina", "anal", "anus", "semen", "crap", "hell", "damn", "piss",
    "bitch", "bastard", "slut", "whore", "dick", "cock", "cum", "hoe", "hoes",
    "nigga", "negros", "retard", "retarded", "gypsy", "abortion", "murder",
    "corpse", "dildo", "orgasm", "erotic", "horny", "ass", "arse",
}
BLOCK |= EXTRA_BLOCK
# Playable words may not contain these at all (catches plurals and compounds).
SUBSTRING_BLOCK = ("fuck", "shit", "cunt", "nigg", "rape", "rapist", "nazi", "slut", "whore", "porn", "sex", "dick", "cock", "bitch", "kill", "murder", "suicid", "penis", "vagin")

# Names and abbreviations that pass the dictionary checks but read as unfair targets.
NOT_PLAYABLE = {
    # Names
    "eric", "kemp", "demi", "sophia", "yates", "ann", "ben", "bob", "dan", "don",
    "joe", "lee", "sam", "tom", "alan", "anna", "dean", "ford", "hong", "jack",
    "jane", "luke", "mary", "mike", "nick", "rick", "ross", "tony", "perkins",
    "forrest", "kong", "paul", "john", "james", "david", "peter", "chris",
    "kevin", "brian", "scott", "adam", "jake", "kate", "lisa", "matt", "ryan",
    "sean", "tim", "jim", "kim", "ted", "ray", "jay", "eve", "jean", "nana",
    "carl", "dave", "gary", "greg", "jeff", "josh", "mark", "neil", "phil",
    "carter", "morgan", "parker", "harris", "cooper", "turner", "walker",
    "wright", "miller", "taylor", "martin", "murphy", "nelson", "morris",
    "hughes", "howard", "clarke", "wilson", "graham", "harvey", "warren",
    "austin", "dallas", "boston", "denver", "vegas", "texas", "paris", "london",
    "berlin", "sydney", "jordan", "chelsea", "arsenal", "diego", "santa",
    "los", "mormon", "midlands", "sept", "tho", "mac", "gen", "non", "mum",
    "anti", "semi", "auto", "electro", "per", "pro", "via", "feds", "min",
    "billy", "china", "dutch", "frank", "harry", "henry", "japan", "jimmy",
    "lewis", "maria", "robin", "roger", "smith",
    "iter", "reit", "tare", "tor", "sol", "ere", "oft", "ode", "nth",
}

SUFFIXES = ["s", "es", "ed", "d", "ing", "er", "ers", "est", "ly", "ies", "ied"]


def in_dictionary(word: str, dictionary: set = lower_dict) -> bool:
    if word in dictionary:
        return True
    for suffix in SUFFIXES:
        if word.endswith(suffix) and len(word) - len(suffix) >= 2:
            stem = word[: -len(suffix)]
            candidates = {stem}
            if suffix in ("ies", "ied"):
                candidates.add(stem + "y")
            if suffix in ("ed", "ing", "er", "est", "ers"):
                candidates.add(stem + "e")
                if len(stem) > 2 and stem[-1] == stem[-2]:
                    candidates.add(stem[:-1])
            if any(c in dictionary for c in candidates):
                return True
    return False


def difficulty(word: str, zipf: float, anagram_count: int) -> int:
    score = 0.0
    score += (len(word) - 3) * 0.55                 # length
    score += max(0.0, 5.2 - zipf) * 0.9             # familiarity
    score += sum(c in RARE_LETTERS for c in word) * 0.5
    score -= min(anagram_count - 1, 3) * 0.25       # more answers = easier
    return max(1, min(5, 1 + int(score)))


accepted = {}
for word in top_n_list("en", 120_000):
    if not re.fullmatch(r"[a-z]+", word):
        continue
    if not MIN_LEN <= len(word) <= MAX_LEN:
        continue
    zipf = zipf_frequency(word, "en")
    if zipf < ACCEPT_ZIPF or word in BLOCK or not in_dictionary(word):
        continue
    accepted[word] = zipf

signatures = {}
for word in accepted:
    signatures.setdefault("".join(sorted(word)), []).append(word)

entries = []
for word, zipf in sorted(accepted.items()):
    group = signatures["".join(sorted(word))]
    playable = (
        zipf >= PLAYABLE_ZIPF
        and (len(word) > 3 or zipf >= COMMON_ZIPF)
        and in_dictionary(word, strict_dict)
        and word not in NOT_PLAYABLE
        and len(set(word)) > 1
        and not any(b in word for b in SUBSTRING_BLOCK)
    )
    entries.append({
        "word": word,
        "length": len(word),
        "difficulty": difficulty(word, zipf, len(group)),
        "frequency": round(min(zipf / 7.0, 1.0), 3),
        "common": zipf >= COMMON_ZIPF,
        "playable": playable,
    })

out = pathlib.Path(__file__).resolve().parent.parent / "Wordfall" / "Resources" / "words.json"
out.write_text(json.dumps(entries, separators=(",", ":")))

playable = [e for e in entries if e["playable"]]
print(f"accepted: {len(entries)}  playable: {len(playable)}  -> {out}")
for n in range(MIN_LEN, MAX_LEN + 1):
    ps = [e for e in playable if e["length"] == n]
    print(n, len(ps), {d: sum(e["difficulty"] == d for e in ps) for d in range(1, 6)})
