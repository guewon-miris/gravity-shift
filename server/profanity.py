"""Multilingual profanity filter.

censor(text) replaces each matched bad word with '#' repeated to the word's
length (so the mask length tracks the word length). Latin-script words are
matched on word boundaries (case-insensitive); CJK / non-latin words are matched
as substrings since they are not space-delimited.

Add or override words by dropping a `profanity_words.txt` (one word per line,
`#` for comments) next to this file.
"""
import re
from pathlib import Path

# Representative common profanity across several languages. Not exhaustive;
# extend via profanity_words.txt.
BASE_WORDS = [
    # English
    "fuck", "shit", "bitch", "asshole", "bastard", "dick", "cunt", "slut", "whore",
    # Korean
    "씨발", "시발", "씨발놈", "병신", "지랄", "개새끼", "새끼", "좆", "존나", "엿먹어", "닥쳐",
    # Japanese
    "くそ", "ばか", "きさま", "死ね", "クソ",
    # Chinese
    "操你", "傻逼", "他妈的", "贱人", "去死",
    # French
    "merde", "putain", "connard", "salope", "enculé",
    # Italian
    "cazzo", "stronzo", "merda", "puttana", "vaffanculo",
    # German
    "scheisse", "scheiße", "arschloch", "schlampe", "hurensohn",
    # Spanish
    "mierda", "puta", "cabron", "cabrón", "gilipollas", "coño",
]

_LATIN_CHARS = set("abcdefghijklmnopqrstuvwxyzàâäéèêëîïôöùûüçñáíóú")
_latin_re: re.Pattern | None = None
_other_words: list[str] = []


def _is_latin(word: str) -> bool:
    return all(c.lower() in _LATIN_CHARS for c in word)


def load() -> None:
    global _latin_re, _other_words
    words = list(BASE_WORDS)
    extra = Path(__file__).parent / "profanity_words.txt"
    if extra.exists():
        for line in extra.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                words.append(line)

    latin = sorted({w.lower() for w in words if w and _is_latin(w)}, key=len, reverse=True)
    _other_words = sorted({w for w in words if w and not _is_latin(w)}, key=len, reverse=True)
    if latin:
        _latin_re = re.compile(r"\b(" + "|".join(re.escape(w) for w in latin) + r")\b", re.IGNORECASE)
    else:
        _latin_re = None


def censor(text: str) -> str:
    if not text:
        return text
    if _latin_re is not None:
        text = _latin_re.sub(lambda m: "#" * len(m.group()), text)
    for w in _other_words:
        if w in text:
            text = text.replace(w, "#" * len(w))
    return text


load()
