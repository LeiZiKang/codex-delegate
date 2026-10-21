# Example: one full Claude → Codex → review loop

A real run on a tiny Python package (`textstats`, two stub functions), recorded on 2026-10-21
with codex-cli 0.160.0. Paths are replaced with `/path/to/...`.

| Step | Who | What happened |
|---|---|---|
| Brief | Claude | Wrote [`brief-textstats.md`](textstats/brief-textstats.md) (constraints, verified facts, spec, report contract) |
| Run | Codex | `run-codex.sh --repo … --notes … --brief …` as a background task. **80 s, ~30k Codex tokens** |
| Report | Codex | [`report-textstats.md`](textstats/report-textstats.md) (9 lines) + 2-line [last message](textstats/last-textstats.txt). Codex fixed one bad test expectation of its own along the way |
| Review | Claude | `git status --short`: only the allowed files. Read the 20-line diff, re-ran `python3 -m unittest discover -s tests` outside the sandbox: 10 tests OK, spot-checked edge cases |
| Commit | Claude | Committed. Final code: [`result-__init__.py`](textstats/result-__init__.py) |

Claude's own cost for this loop is the brief, about 40 lines of script output, the report and
a short diff. All of Codex's exploration and test iterations stayed on Codex's side.
