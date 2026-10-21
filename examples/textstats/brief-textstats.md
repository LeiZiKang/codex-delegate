# Codex task textstats: implement word_count and top_words with tests

Repo: /path/to/demo-repo
Notes dir: /path/to/notes

## Hard constraints (highest priority)
- Do NOT commit, push, create branches, or rewrite git history.
- Only change: textstats/__init__.py and a new tests/ directory. Do not touch README.md.
- No new dependencies: standard library only (Python 3.9, unittest).

## Background
Tiny demo package used to test a Claude -> Codex delegation loop.

## Verified facts (do not re-investigate)
- The package is a single file, textstats/__init__.py, with two stubs raising NotImplementedError.
- `python3` is 3.9.6. Run tests with: `python3 -m unittest discover -s tests -v` from the repo root.

## What to do
1. `word_count(text)`: number of words. A word is a maximal run of letters, digits or
   apostrophes (regex `[A-Za-z0-9']+`); case-insensitive; empty/whitespace text -> 0.
2. `top_words(text, n=3)`: the n most frequent words, lowercased, as `(word, count)` tuples,
   sorted by count descending, then word ascending for ties. `n <= 0` -> `[]`.
   Raise `TypeError` if `text` is not a str (both functions).
3. Add tests/test_textstats.py (unittest) covering: normal sentence, punctuation, case folding,
   apostrophes ("don't"), tie ordering, n larger than vocabulary, n <= 0, empty text, TypeError.
Out of scope: CLI, packaging, type stubs, docs.

## Verification (inside your sandbox)
- `python3 -m unittest discover -s tests -v` must pass.

## Report
Write the report ONLY to `/path/to/notes/report-textstats.md` (NEVER inside the repo), at most 10 lines:
- Done / not done
- Files changed
- Commands run and their result (test count)
- What Claude must verify outside the sandbox
Keep your final chat message to 3 lines; the report is the source of truth.
