#!/usr/bin/env python3
"""Build a 8,000–10,000 word vocabulary JSON for MyEnglishCoach."""

from __future__ import annotations

import csv
import json
import re
from pathlib import Path

ROOT = Path("/Users/minghaowang/Desktop/MyEnglishCoach")
OUT = ROOT / "MyEnglishCoach/Resources/vocabulary.json"
EXISTING = OUT
GOOGLE = Path("/Users/minghaowang/.cursor/projects/Users-minghaowang-Desktop-MyEnglishCoach/agent-tools/f8661cbb-d22a-4e6d-b2df-939af185f61f.txt")
ECDICT = Path("/tmp/ecdict.csv")
TARGET = 9500
TARGET_MAX = 10000

FUNCTION_WORDS = {
    "a", "an", "the", "and", "or", "but", "nor", "so", "yet", "both", "either",
    "neither", "not", "no", "yes", "ok", "oh", "hey", "hi", "hello",
    "i", "me", "my", "mine", "myself", "you", "your", "yours", "yourself",
    "he", "him", "his", "himself", "she", "her", "hers", "herself",
    "it", "its", "itself", "we", "us", "our", "ours", "ourselves",
    "they", "them", "their", "theirs", "themselves",
    "this", "that", "these", "those", "who", "whom", "whose", "which", "what",
    "when", "where", "why", "how", "if", "than", "then", "too", "very",
    "just", "also", "only", "even", "still", "already", "always", "never",
    "of", "to", "in", "for", "on", "with", "at", "by", "from", "as", "into",
    "about", "between", "through", "during", "before", "after", "above",
    "below", "under", "over", "again", "once", "here", "there",
    "is", "am", "are", "was", "were", "been", "being",
    "s", "t", "re", "ve", "ll", "d", "m",
}

SKIP_WORDS = {
    "facebook", "twitter", "google", "yahoo", "hotmail", "paypal", "ebay",
    "icq", "msn", "html", "http", "https", "www", "com", "org", "net",
    "pdf", "jpg", "gif", "click", "login", "logout", "username",
}

IRREGULAR = {
    "arise": ("arose", "arisen", "arising"),
    "awake": ("awoke", "awoken", "awaking"),
    "be": ("was/were", "been", "being"),
    "bear": ("bore", "borne", "bearing"),
    "beat": ("beat", "beaten", "beating"),
    "become": ("became", "become", "becoming"),
    "begin": ("began", "begun", "beginning"),
    "bend": ("bent", "bent", "bending"),
    "bet": ("bet", "bet", "betting"),
    "bind": ("bound", "bound", "binding"),
    "bite": ("bit", "bitten", "biting"),
    "bleed": ("bled", "bled", "bleeding"),
    "blow": ("blew", "blown", "blowing"),
    "break": ("broke", "broken", "breaking"),
    "breed": ("bred", "bred", "breeding"),
    "bring": ("brought", "brought", "bringing"),
    "build": ("built", "built", "building"),
    "burn": ("burnt", "burnt", "burning"),
    "burst": ("burst", "burst", "bursting"),
    "buy": ("bought", "bought", "buying"),
    "cast": ("cast", "cast", "casting"),
    "catch": ("caught", "caught", "catching"),
    "choose": ("chose", "chosen", "choosing"),
    "cling": ("clung", "clung", "clinging"),
    "come": ("came", "come", "coming"),
    "cost": ("cost", "cost", "costing"),
    "creep": ("crept", "crept", "creeping"),
    "cut": ("cut", "cut", "cutting"),
    "deal": ("dealt", "dealt", "dealing"),
    "dig": ("dug", "dug", "digging"),
    "do": ("did", "done", "doing"),
    "draw": ("drew", "drawn", "drawing"),
    "dream": ("dreamt", "dreamt", "dreaming"),
    "drink": ("drank", "drunk", "drinking"),
    "drive": ("drove", "driven", "driving"),
    "eat": ("ate", "eaten", "eating"),
    "fall": ("fell", "fallen", "falling"),
    "feed": ("fed", "fed", "feeding"),
    "feel": ("felt", "felt", "feeling"),
    "fight": ("fought", "fought", "fighting"),
    "find": ("found", "found", "finding"),
    "fit": ("fit", "fit", "fitting"),
    "flee": ("fled", "fled", "fleeing"),
    "fling": ("flung", "flung", "flinging"),
    "fly": ("flew", "flown", "flying"),
    "forbid": ("forbade", "forbidden", "forbidding"),
    "forecast": ("forecast", "forecast", "forecasting"),
    "forget": ("forgot", "forgotten", "forgetting"),
    "forgive": ("forgave", "forgiven", "forgiving"),
    "freeze": ("froze", "frozen", "freezing"),
    "get": ("got", "gotten", "getting"),
    "give": ("gave", "given", "giving"),
    "go": ("went", "gone", "going"),
    "grind": ("ground", "ground", "grinding"),
    "grow": ("grew", "grown", "growing"),
    "hang": ("hung", "hung", "hanging"),
    "have": ("had", "had", "having"),
    "hear": ("heard", "heard", "hearing"),
    "hide": ("hid", "hidden", "hiding"),
    "hit": ("hit", "hit", "hitting"),
    "hold": ("held", "held", "holding"),
    "hurt": ("hurt", "hurt", "hurting"),
    "keep": ("kept", "kept", "keeping"),
    "kneel": ("knelt", "knelt", "kneeling"),
    "know": ("knew", "known", "knowing"),
    "lay": ("laid", "laid", "laying"),
    "lead": ("led", "led", "leading"),
    "lean": ("leant", "leant", "leaning"),
    "leap": ("leapt", "leapt", "leaping"),
    "learn": ("learnt", "learnt", "learning"),
    "leave": ("left", "left", "leaving"),
    "lend": ("lent", "lent", "lending"),
    "let": ("let", "let", "letting"),
    "lie": ("lay", "lain", "lying"),
    "light": ("lit", "lit", "lighting"),
    "lose": ("lost", "lost", "losing"),
    "make": ("made", "made", "making"),
    "mean": ("meant", "meant", "meaning"),
    "meet": ("met", "met", "meeting"),
    "pay": ("paid", "paid", "paying"),
    "prove": ("proved", "proven", "proving"),
    "put": ("put", "put", "putting"),
    "quit": ("quit", "quit", "quitting"),
    "read": ("read", "read", "reading"),
    "ride": ("rode", "ridden", "riding"),
    "ring": ("rang", "rung", "ringing"),
    "rise": ("rose", "risen", "rising"),
    "run": ("ran", "run", "running"),
    "say": ("said", "said", "saying"),
    "see": ("saw", "seen", "seeing"),
    "seek": ("sought", "sought", "seeking"),
    "sell": ("sold", "sold", "selling"),
    "send": ("sent", "sent", "sending"),
    "set": ("set", "set", "setting"),
    "sew": ("sewed", "sewn", "sewing"),
    "shake": ("shook", "shaken", "shaking"),
    "shine": ("shone", "shone", "shining"),
    "shoot": ("shot", "shot", "shooting"),
    "show": ("showed", "shown", "showing"),
    "shrink": ("shrank", "shrunk", "shrinking"),
    "shut": ("shut", "shut", "shutting"),
    "sing": ("sang", "sung", "singing"),
    "sink": ("sank", "sunk", "sinking"),
    "sit": ("sat", "sat", "sitting"),
    "sleep": ("slept", "slept", "sleeping"),
    "slide": ("slid", "slid", "sliding"),
    "speak": ("spoke", "spoken", "speaking"),
    "speed": ("sped", "sped", "speeding"),
    "spell": ("spelt", "spelt", "spelling"),
    "spend": ("spent", "spent", "spending"),
    "spill": ("spilt", "spilt", "spilling"),
    "spin": ("spun", "spun", "spinning"),
    "spit": ("spat", "spat", "spitting"),
    "split": ("split", "split", "splitting"),
    "spoil": ("spoilt", "spoilt", "spoiling"),
    "spread": ("spread", "spread", "spreading"),
    "spring": ("sprang", "sprung", "springing"),
    "stand": ("stood", "stood", "standing"),
    "steal": ("stole", "stolen", "stealing"),
    "stick": ("stuck", "stuck", "sticking"),
    "sting": ("stung", "stung", "stinging"),
    "stink": ("stank", "stunk", "stinking"),
    "strike": ("struck", "struck", "striking"),
    "swear": ("swore", "sworn", "swearing"),
    "sweep": ("swept", "swept", "sweeping"),
    "swim": ("swam", "swum", "swimming"),
    "swing": ("swung", "swung", "swinging"),
    "take": ("took", "taken", "taking"),
    "teach": ("taught", "taught", "teaching"),
    "tear": ("tore", "torn", "tearing"),
    "tell": ("told", "told", "telling"),
    "think": ("thought", "thought", "thinking"),
    "throw": ("threw", "thrown", "throwing"),
    "thrust": ("thrust", "thrust", "thrusting"),
    "understand": ("understood", "understood", "understanding"),
    "wake": ("woke", "woken", "waking"),
    "wear": ("wore", "worn", "wearing"),
    "weave": ("wove", "woven", "weaving"),
    "weep": ("wept", "wept", "weeping"),
    "win": ("won", "won", "winning"),
    "wind": ("wound", "wound", "winding"),
    "withdraw": ("withdrew", "withdrawn", "withdrawing"),
    "write": ("wrote", "written", "writing"),
}

PHRASAL_VERBS = [
    "look up", "look after", "look for", "look into", "look out", "look over",
    "look forward to", "put on", "put off", "put out", "put up with", "put away",
    "put back", "put down", "take off", "take on", "take over", "take up",
    "take care of", "take out", "take in", "take after", "turn on", "turn off",
    "turn down", "turn up", "turn out", "turn into", "pick up", "pick out",
    "give up", "give in", "give out", "give away", "give back", "find out",
    "carry out", "carry on", "set up", "set off", "set out", "break down",
    "break up", "break out", "break into", "come up with", "come across",
    "come out", "come in", "come over", "come up", "work out", "fill out",
    "fill in", "go over", "go through", "go on", "go off", "go out", "go along with",
    "get over", "get along", "get back", "get up", "get off", "get on",
    "get rid of", "get out", "figure out", "deal with", "check out", "check in",
    "call off", "call back", "bring up", "bring about", "bring back",
    "run out of", "run into", "run over", "show up", "show off",
    "watch out", "write down", "write off", "catch up", "catch on",
    "fall behind", "fall out", "fall apart", "drop off", "drop out",
    "hold on", "hold back", "keep up", "keep on", "keep off",
    "make up", "make out", "pass out", "pass away", "pass on",
    "throw away", "throw up", "wake up", "grow up", "end up",
    "point out", "sort out", "try on", "try out", "hang on", "hang out",
    "hang up", "log in", "log out", "sign up", "sign in", "sign out",
    "shut down", "shut up", "cut off", "cut down", "cut out",
    "blow up", "blow out", "calm down", "slow down", "speed up",
    "warm up", "cool down", "clean up", "clear up", "close down",
    "come back", "come down", "come from", "do over", "do without",
    "eat out", "fall down", "fill up", "follow up", "get in", "get through",
    "give off", "go back", "go down", "go up", "hand in", "hand out",
    "help out", "keep out", "leave out", "let down", "let in", "let off",
    "look back", "look down on", "move in", "move out", "pay back", "pay off",
    "pull out", "pull over", "push back", "put together", "put through",
    "rely on", "send back", "set down", "settle down", "stand up",
    "stay up", "stick to", "switch off", "switch on", "take back",
    "talk over", "think over", "turn around", "turn back", "use up",
    "wear out", "work on", "work through", "back up", "break off",
    "bring in", "build up", "call on", "carry over", "check off",
    "come about", "come along", "count on", "cover up", "cross out",
    "do away with", "draw up", "drop by", "fall through", "feel up to",
    "get away", "get by", "go after", "go ahead", "go with",
    "hold up", "keep from", "lay off", "leave behind", "live up to",
    "look up to", "make up for", "mix up", "pass by", "pick on",
    "put aside", "put forward", "run away", "see off", "set aside",
    "show around", "shut off", "sit down", "stand by", "stand for",
    "take apart", "take down", "think about", "turn over", "wait on",
    "walk out", "watch over", "wear off", "wipe out", "zip up",
    "account for", "add up", "ask for", "back out", "blow over",
    "boil down to", "branch out", "brush up", "bump into", "burn out",
    "call for", "call up", "care for", "catch up with", "check up on",
    "chip in", "come down with", "come up against", "cut back",
    "die out", "do up", "dress up", "drop in", "face up to",
    "fall back on", "fit in", "fix up", "focus on", "get across",
    "get ahead", "get around", "get down to", "give in to",
    "go through with", "grow out of", "hand over", "head for",
    "hold on to", "keep up with", "knock out", "lay down", "let out",
    "look around", "make do with", "mess up", "move on", "nod off",
    "own up", "pack up", "pass down", "phase out", "play down",
    "pop up", "rule out", "run down", "see through", "sell out",
    "send off", "set back", "settle for", "shake off", "show in",
    "shut out", "spell out", "stand out", "start over", "stay out",
    "step down", "step up", "stick around", "sum up", "take after",
    "talk back", "tear down", "tell off", "think through", "throw out",
    "tide over", "tire out", "touch on", "track down", "trade in",
    "try out for", "turn away", "use up", "wait up", "wash up",
    "wear away", "wind up", "work out to", "zero in on",
]

TRADES = [
    "torque", "scaffold", "lockout", "voltage", "blueprint", "apprentice",
    "supervisor", "hazard", "precaution", "specification", "measurement",
    "tolerance", "alignment", "millimetre", "millimeter", "valve", "circuit",
    "ppe", "hardhat", "goggles", "respirator", "harness", "excavation",
    "conduit", "breaker", "ammeter", "multimeter", "caliper", "spanner",
    "wrench", "screwdriver", "pliers", "chisel", "mallet", "lathe", "mill",
    "welder", "electrode", "solder", "flux", "rebar", "concrete", "formwork",
    "joist", "truss", "beam", "girder", "fastener", "bolt", "nut", "washer",
    "rivet", "gasket", "bearing", "pulley", "gear", "shaft", "coupling",
    "hose", "pipefitter", "plumber", "electrician", "carpenter", "millwright",
    "machinist", "hvac", "refrigerant", "ductwork", "insulation", "grounding",
    "earthing", "ampere", "watt", "ohm", "wattage", "current", "neutral",
    "livewire", "shortcircuit", "overload", "fuse", "relay", "contactor",
    "schematic", "isometric", "elevation", "section", "scale", "dimension",
    "clearance", "allowance", "inspection", "audit", "compliance", "whmis",
    "msds", "sds", "lockout", "tagout", "confined", "excavation", "trenching",
    "shoring", "guardrail", "toeboard", "lanyard", "carabiner", "rigging",
    "sling", "hoist", "crane", "forklift", "pallet", "skid", "job hazard",
    "near miss", "incident", "first aid", "eyewash", "fire extinguisher",
    "emergency exit", "muster", "toolbox meeting", "permit", "hot work",
    "cold work", "isolation", "de-energize", "energize", "test before touch",
    "csa", "worksafe", "bcit", "admission", "assessment", "equivalent",
    "requirement", "tradesperson", "journeyman", "red seal", "indenture",
    "shop drawing", "as-built", "commissioning", "handover", "punch list",
    "rfi", "change order", "quantity", "estimate", "takeoff", "bill of materials",
    "kit", "spare", "preventive", "corrective", "troubleshooting", "diagnose",
    "calibrate", "lubricate", "tighten", "torque wrench", "thread", "pitch",
    "gauge", "feeler", "spirit level", "plumb", "square", "flush", "level",
    "load bearing", "dead load", "live load", "safety factor", "ppe",
]

AWL = """
abandon abstract academy access accommodate accompany accumulate accurate achieve
acknowledge acquire adapt adequate adjacent adjust administrate adult advocate
affect aggregate aid albeit allocate alter alternative ambiguous amend analogy
analyse analyze annual anticipate apparent append appreciate approach appropriate
approximate arbitrary area aspect assemble assess assign assist assume assure
attach attain attitude attribute author authority automate available aware behalf
benefit bias bond brief bulk capable capacity category cease challenge channel
chapter chart chemical circumstance cite civil clarify classic clause code
coherent coincide collapse colleague commence comment commission commit commodity
communicate community compatible compensate compile complement complex component
compound comprehensive comprise compute conceive concentrate concept conclude
concurrent conduct confer confine confirm conflict conform consent consequent
considerable consist constant constitute constrain construct consult consume
contact contemporary context contract contradict contrary contrast contribute
controversy convene converse convert convince cooperate coordinate core corporate
correspond couple create credit criteria crucial culture currency cycle data
debate decade decline deduce define definite demonstrate denote deny depress
derive design despite detect deviate device devote differentiate dimension
diminish discrete discriminate displace display dispose distinct distort
distribute diverse document domain domestic dominate draft drama duration dynamic
economy edit element eliminate emerge emphasis empirical enable encounter energy
enforce enhance enormous ensure entity environment equate equip equivalent erode
error establish estate estimate ethic ethnic evaluate eventual evident evolve
exceed exclude exhibit expand expert explicit exploit export expose external
extract facilitate factor feature federal fee file final finance finite flexible
fluctuate focus format formula forthcoming found foundation framework function
fund fundamental furthermore gender generate generation globe goal grade grant
guarantee guideline hence hierarchy highlight hypothesis identical identify
ideology ignorant illustrate image immigrate impact implement implicate implicit
imply impose incentive incidence incline income incorporate index indicate
individual induce inevitable infer infrastructure inherent inhibit initial
initiate injure innovate input insert insight inspect instance institute instruct
integral integrate integrity intelligence intense interact intermediate internal
interpret interval intervene intrinsic invest investigate invoke involve isolate
issue item journal justify label labour layer lecture legal legislate levy
liberal licence likewise link locate logic maintain majority manipulate manual
margin mature maximise maximize mechanism media mediate medical medium mental
method migrate military minimal minimise minimize minimum ministry minor mode
modify monitor motive mutual negate network neutral nevertheless nonetheless
norm normal notion notwithstanding nuclear objective obtain obvious occupy occur
odd offset ongoing option orient outcome output overall overlap overseas panel
paradigm paragraph parallel parameter participate partner passive perceive
percent period persist perspective phase phenomenon philosophy physical plus
policy portion pose positive potential practitioner precede precise predict
predominant preliminary presume previous primary prime principal principle prior
priority proceed process professional prohibit project promote proportion
prospect protocol psychology publication publish purchase pursue qualitative
quote radical random range ratio rational react recover refine regime region
register regulate reinforce reject relax release relevant reluctance rely remove
require research reside resolve resource respond restore restrain restrict retain
reveal revenue reverse revise revolution rigid role route scenario schedule
scheme scope section sector secure seek select sequence series shift significant
similar simulate site sole somewhat source specific specify sphere stable
statistic status straightforward strategy stress structure style submit
subordinate subsequent subsidy substitute successor sufficient sum summary
supplement survey survive suspect sustain symbol tape target task team technical
technique technology temporary tense terminate text theme theory thereby thesis
topic trace tradition transfer transform transit transmit transport trend trigger
ultimate undergo underlie undertake uniform unify unique utilise utilize valid
vary vehicle version via violate virtual visible vision visual volume voluntary
welfare whereas whereby widespread
""".split()

VERBS = {
    "look", "take", "get", "put", "go", "come", "give", "make", "break", "carry",
    "set", "turn", "run", "hold", "keep", "work", "fill", "find", "pick", "bring",
    "call", "check", "deal", "figure", "fall", "show", "throw", "write", "watch",
    "wake", "drop", "hang", "pass", "pull", "push", "cut", "blow", "kick", "lay",
    "let", "live", "move", "pay", "stand", "start", "stick", "talk", "think",
    "try", "wait", "walk", "wear", "win", "back", "end", "point", "sort", "catch",
    "sit", "speak", "shut", "send", "grow", "build", "hand", "slow", "speed",
    "warm", "clean", "clear", "close", "do", "eat", "follow", "help", "leave",
    "log", "sign", "switch", "use", "rely", "settle", "stay", "sum", "account",
    "add", "ask", "boil", "branch", "brush", "bump", "burn", "care", "chip",
    "count", "cover", "cross", "die", "draw", "dress", "face", "fit", "fix",
    "focus", "head", "knock", "mix", "own", "pack", "phase", "play", "pop",
    "rule", "see", "sell", "shake", "spell", "step", "tear", "tell", "tide",
    "tire", "touch", "track", "trade", "turn", "wash", "wind", "zero", "bring",
}

PARTICLES = {
    "up", "down", "off", "on", "out", "in", "away", "over", "back", "through",
    "around", "about", "along", "aside", "apart", "into", "after", "for", "of",
    "to", "with", "forward", "together", "across", "by", "ahead", "behind",
    "upon", "against", "without", "from",
}

WORD_RE = re.compile(r"^[A-Za-z][A-Za-z\-']*$")
PHRASE_RE = re.compile(r"^[a-z]+(?: [a-z]+){1,3}$")
POS_PREFIX = re.compile(
    r"^(?:vt|vi|aux|art|num|int|prep|conj|pron|adj|adv|ad|pl|abbr|web|n|v|a)\.\s*",
    re.I,
)


def clean_zh(text: str) -> str:
    if not text:
        return ""
    text = text.replace("\\n", "\n")
    parts: list[str] = []
    for raw in text.split("\n"):
        line = raw.strip()
        if not line or line.startswith("[网络]") or line.startswith("[计]") and "网络" in line:
            continue
        if line.startswith("[") and line.endswith("]") and len(line) < 8:
            continue
        line = re.sub(r"^(\[[^\]]+\]\s*)+", "", line)
        for _ in range(3):
            line = POS_PREFIX.sub("", line)
        line = re.sub(r"^[a-z]{1,5}\.\s*", "", line, flags=re.I)
        line = line.replace("；", ";").split(";")[0]
        line = re.sub(r"\s+", "", line) if re.fullmatch(r"[\u4e00-\u9fff\s，、/（）()·]+", line) else line
        line = line.strip(" .;；,，")
        if not line:
            continue
        if len(re.findall(r"[A-Za-z]", line)) > 12:
            continue
        parts.append(line)
        if len(parts) >= 2:
            break
    zh = "；".join(parts)
    return zh[:40].rstrip("；;，,")


def phonetic(raw: str) -> str:
    raw = (raw or "").strip()
    if not raw:
        return ""
    raw = raw.strip("/")
    return f"/{raw}/"


def parse_exchange(raw: str) -> dict[str, str]:
    out: dict[str, str] = {}
    if not raw:
        return out
    for part in raw.split("/"):
        if ":" in part:
            key, value = part.split(":", 1)
            out[key] = value
    return out


def rank(row: dict) -> tuple:
    def num(key: str, missing: int) -> int:
        try:
            value = int(row.get(key) or 0)
            return missing if value <= 0 else value
        except ValueError:
            return missing

    collins = int(row.get("collins") or 0)
    oxford = 0 if not (row.get("oxford") or "").strip() else 1
    return (-collins, -oxford, num("bnc", 9_999_999), num("frq", 9_999_999))


def load_ecdict(path: Path) -> dict[str, dict]:
    best: dict[str, dict] = {}
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            word = (row.get("word") or "").strip()
            if not word:
                continue
            key = word.lower()
            previous = best.get(key)
            if previous is None or rank(row) < rank(previous):
                row["_surface"] = word
                best[key] = row
    return best


def category_for(english: str, tags: str) -> str:
    key = english.lower()
    if key in IRREGULAR:
        return "irregularVerb"
    if " " in key:
        return "phrasalVerb"
    if key in {w.lower() for w in TRADES}:
        return "trades"
    if key in {w.lower() for w in AWL}:
        return "academic"
    return "core"


def make_id(english: str, category: str, used: set[str]) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", english.lower()).strip("_")
    prefix = {
        "irregularVerb": "iv",
        "phrasalVerb": "pv",
        "academic": "ac",
        "trades": "tr",
        "core": "c",
    }[category]
    base = f"{prefix}_{slug}"
    candidate = base
    n = 2
    while candidate in used:
        candidate = f"{base}_{n}"
        n += 1
    used.add(candidate)
    return candidate


def item_from_row(english: str, row: dict | None, category: str, used_ids: set[str]) -> dict | None:
    zh = clean_zh(row.get("translation", "") if row else "")
    if not zh:
        return None
    forms = IRREGULAR.get(english.lower())
    exchange = parse_exchange(row.get("exchange", "") if row else "")
    past = forms[0] if forms else None
    pp = forms[1] if forms else None
    gerund = forms[2] if forms else None
    if category == "irregularVerb":
        past = past or exchange.get("p")
        pp = pp or exchange.get("d")
        gerund = gerund or exchange.get("i")
    accepted: list[str] = []
    if english.lower() == "get":
        accepted = ["got"]
    if past and "/" in past:
        accepted.extend(p.strip() for p in past.split("/") if p.strip())
    example_en = f'You will see "{english}" in workplace and classroom English.'
    example_zh = f"在课堂和工地英语里都会见到「{english}」（{zh}）。"
    payload = {
        "id": make_id(english, category, used_ids),
        "english": english,
        "chinese": zh,
        "phonetic": phonetic(row.get("phonetic", "") if row else ""),
        "category": category,
        "past": past,
        "pastParticiple": pp,
        "gerund": gerund,
        "exampleEn": example_en,
        "exampleZh": example_zh,
        "accepted": accepted,
    }
    return {key: value for key, value in payload.items() if value is not None}


def keep_existing(entry: dict, used_ids: set[str], used_en: set[str]) -> dict:
    used_ids.add(entry["id"])
    used_en.add(entry["english"].lower())
    return entry


def main() -> None:
    raw_existing = json.loads(EXISTING.read_text())["words"]
    existing = [
        entry for entry in raw_existing
        if not str(entry.get("exampleEn", "")).startswith("You will see")
    ]
    google = [
        line.strip().lower()
        for line in GOOGLE.read_text().splitlines()
        if line.strip()
    ]
    print("loading ECDICT…")
    ecdict = load_ecdict(ECDICT)
    print("ecdict keys", len(ecdict))

    used_ids: set[str] = set()
    used_en: set[str] = set()
    words: list[dict] = []

    for entry in existing:
        words.append(keep_existing(entry, used_ids, used_en))

    def is_inflected_form(key: str, row: dict | None) -> bool:
        if not row:
            return False
        lemma = parse_exchange(row.get("exchange") or "").get("0", "").lower()
        return bool(lemma and lemma != key)

    def add(english: str, category: str | None = None) -> None:
        key = english.strip().lower()
        if not key or key in used_en:
            return
        if key in SKIP_WORDS or key in FUNCTION_WORDS:
            return
        if " " in key:
            if not PHRASE_RE.match(key):
                return
        elif not WORD_RE.match(key):
            return
        row = ecdict.get(key)
        if category is None and is_inflected_form(key, row):
            return
        cat = category or category_for(key, row.get("tag", "") if row else "")
        item = item_from_row(english if " " in english else key, row, cat, used_ids)
        if item is None:
            return
        if " " in english:
            item["english"] = key
        words.append(item)
        used_en.add(key)

    for lemma in IRREGULAR:
        add(lemma, "irregularVerb")
    for phrase in PHRASAL_VERBS:
        add(phrase, "phrasalVerb")
    for term in TRADES:
        add(term, "trades")
    for term in AWL:
        add(term, "academic")

    for term in google:
        if len(words) >= TARGET:
            break
        add(term)

    # Extra high-school / exam tagged lemmas, frequency first.
    extras = []
    for key, row in ecdict.items():
        if key in used_en or key in FUNCTION_WORDS or key in SKIP_WORDS:
            continue
        if not WORD_RE.match(key):
            continue
        if is_inflected_form(key, row):
            continue
        tag = row.get("tag") or ""
        if not any(token in tag for token in ("zk", "gk", "cet4", "cet6", "ielts", "toefl", "ky")):
            continue
        extras.append((rank(row), key))
    extras.sort()
    for _, key in extras:
        if len(words) >= TARGET:
            break
        add(key)

    # Quality phrasal verbs from ECDICT to enrich the bank.
    extra_phrasals = []
    for key, row in ecdict.items():
        if key in used_en:
            continue
        parts = key.split()
        if len(parts) not in (2, 3):
            continue
        if parts[0] not in VERBS:
            continue
        if not all(part.isalpha() for part in parts):
            continue
        if parts[-1] not in PARTICLES and (len(parts) < 3 or parts[1] not in PARTICLES):
            continue
        if not (row.get("translation") or "").strip():
            continue
        extra_phrasals.append((rank(row), key))
    extra_phrasals.sort()
    for _, key in extra_phrasals:
        if len(words) >= TARGET_MAX:
            break
        if sum(1 for w in words if w["category"] == "phrasalVerb") >= 700:
            break
        add(key, "phrasalVerb")

    if len(words) > TARGET_MAX:
        words[:] = words[:TARGET_MAX]

    OUT.write_text(json.dumps({"words": words}, ensure_ascii=False, separators=(",", ":")))
    counts: dict[str, int] = {}
    for item in words:
        counts[item["category"]] = counts.get(item["category"], 0) + 1
    print("total", len(words), "bytes", OUT.stat().st_size)
    print(counts)
    missing_zh = sum(1 for w in words if not w.get("chinese"))
    print("missing chinese", missing_zh)


if __name__ == "__main__":
    main()
