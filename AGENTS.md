Think before coding. State your assumptions out loud. If the request is ambiguous, ask. If a simpler approach exists, push back. Stop when you are confused, name what is unclear, do not just pick one interpretation and run.

Simplicity first. Write the minimum code that solves the problem. No speculative abstractions. No flexibility nobody asked for. The test: would a senior engineer call this overcomplicated.

Surgical changes. Touch only what the task requires. Do not improve neighboring code. Do not refactor what is not broken. Every changed line should trace back to the request.

Goal-driven execution. Turn vague instructions into verifiable targets before writing a line. “Add validation” becomes “write tests for invalid inputs, then make them pass.”

For long markdown files, use the `manual/md-index.sh` script to get an index of the file first. This will help you understand the structure of the file and find the relevant sections. Never read full markdown files if they are over 150 lines (use `wc -l` command).

For small/localized tasks, do not read project-wide docs by default. First inspect only the directly related files, nearby code, and relevant tests.

If a directly relevant markdown file is long or you are unsure which section matters, run `manual/md-index.sh <file>` before reading it. Do not index or read all project docs by default.

The project overview files are `README.md`, `proposal.md`, `manual/README.md`, and `manual/protocol.md`. Read them only for broad onboarding, architecture questions, or tasks that span multiple areas.

