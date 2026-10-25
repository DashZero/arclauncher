## 10. Working with several agents (addition, from the AI delegation playbook)

This section only adds to sections 0 to 9 of `AGENTS.md`. If anything here conflicts with them (plan approval, one phase at a time, never removing Arc features, hard constraints), sections 0 to 9 win. Full background: `C:\GitHub\ai-delegation-playbook\docs\WORKFLOW_PLAYBOOK.md`; copy-paste briefs and reports: `docs\TEMPLATES.md` in the same folder. Model names and prices in the playbook are a Read2Go snapshot, so do not copy them here.

- **Choose by risk and cost.** Use the cheapest model whose output a measurable check can verify (a build, an analyzer run, a test, a number on the TV). Use the strongest model only where a mistake is expensive: API keys and config handling, the local HTTP server, the Home button approach, drift migrations, and kid age filtering.
- **Never trust a report; reproduce it.** Re-run `flutter analyze`, the tests and the build yourself, and open the file and line a report cites. Say plainly what was not run, and what the owner must test on the TV.
- **Author and reviewer are different sessions.** Review the risky parts (section 2 constraints, the kid filter, schema migrations) in a separate session at higher effort before merge. Nobody reviews their own work or merges their own branch.
- **One job, one worktree, one branch.** One brief covers one phase step with one measurable outcome (for example "wallpaper cache stays under 25 MB"). Two writers never touch the same files; merge one branch at a time and re-run analyze and tests on the merged result.
- **Briefs are committed and pushed before anyone is told to run them.** A handover that is not pushed does not count; state the commit hash and branch. Keep briefs, reports and `session-handoff-N.md` notes (under 70 lines: state, branches in flight, how to verify, waiting on the owner, next steps) in a `handoff/` folder.
- **Stop after two failed attempts.** Escalate to a stronger model or ask the owner; do not loop.
- **Environment failures look like code failures.** Check the FVM Flutter version (`.fvmrc`) and that code generation ran before believing a failing build or test.
- **Keep business and legal topics out of build sessions.** Park them in a document and wait for the owner to ask.
- **Keep chat short.** Search before reading, read only the lines you need, and do not re-verify what a tool already confirmed.
