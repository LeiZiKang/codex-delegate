"""Tiny text statistics helpers (demo project for codex-delegate)."""

import re
from collections import Counter


def _words(text: str) -> list[str]:
    if not isinstance(text, str):
        raise TypeError("text must be a str")
    return [word.lower() for word in re.findall(r"[A-Za-z0-9']+", text)]


def word_count(text: str) -> int:
    return len(_words(text))


def top_words(text: str, n: int = 3) -> list[tuple[str, int]]:
    words = _words(text)
    if n <= 0:
        return []
    return sorted(Counter(words).items(), key=lambda item: (-item[1], item[0]))[:n]
