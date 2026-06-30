<!-- Thanks for contributing to RosterFocus! -->
<!-- Code PRs target `dev`. Documentation-only PRs may target `main` (apply `skip-changelog`). -->

## Summary

<!-- What does this change do, and why? -->

## How to test

<!-- CLI: which rosterfocus.py flags to run and expected output.
     App: how to build/run (xcodegen + build-local.sh), what to click, what you should see.
     Include a screenshot/clip for visible app behavior. -->

## Checklist

- [ ] Added a **`CHANGELOG.md`** entry under `## Unreleased` (or applied `skip-changelog` for a trivial/docs-only change)
- [ ] Tests pass — `xcodebuild test … CODE_SIGNING_ALLOWED=NO` (app) and/or `rosterfocus.py --validate` / `--doctor` (CLI)
- [ ] CLI and app behavior stay in sync (priority order, keyword match, lead/trail, act-only-on-change)
- [ ] No secrets or personal data added (this is a public repo)
