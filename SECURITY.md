# Security Policy

Thanks for helping keep RosterFocus safe.

## Reporting a vulnerability

**Please don't report security vulnerabilities through public GitHub issues, discussions, or
pull requests** — a public report discloses the problem before a fix exists.

Instead, report it privately via GitHub's
**[Report a vulnerability](https://github.com/TemujinCalidius/roster-focus/security/advisories/new)**
form (the repo's **Security → Advisories → Report a vulnerability**). Only the maintainers can see it.

Please include what you can:

- the affected file(s) / component / version (CLI vs app),
- the impact and how it could be exploited,
- steps to reproduce or a proof of concept,
- any suggested fix.

## What happens next

RosterFocus is small and mostly solo-maintained, so this is best-effort:

1. We aim to **acknowledge** your report within a few days.
2. We confirm the issue and develop a fix **privately**.
3. We **release the fix first**, then publish a **GitHub Security Advisory** (requesting a CVE
   where warranted) and **credit you** — unless you'd prefer to stay anonymous.

We practice **coordinated disclosure**: please give us a reasonable window to ship a fix before
disclosing publicly.

## Supported versions

Security fixes ship against the **latest release** only.

| Version | Supported |
|---------|-----------|
| Latest release | ✅ |
| Anything older | ❌ — please update |

## Where to look (scope)

RosterFocus runs **on your own Mac** and touches a few sensitive areas; these are in scope:

- **Calendar data (EventKit).** It reads your shift calendars to decide a Focus. Report
  anything that could leak calendar data or read more than the configured calendars.
- **Running Shortcuts.** It executes `/usr/bin/shortcuts run "<name>"` with names from your
  config. Report any path that could run an unintended command or be injected.
- **Config / state files** at `~/.config/roster-focus/`. Report unsafe parsing or writes.
- **Signing / distribution.** The released app is Developer ID-signed, notarized, and stapled,
  and runs hardened-runtime + the minimum entitlements (calendars + Apple Events for
  Shortcuts, no sandbox so it can exec `/usr/bin/shortcuts` and read `~/.config`). Report a
  weakened signature, an over-broad entitlement, or a tampering vector.

**Out of scope:** your own calendar contents or Shortcuts, bugs in macOS/EventKit/Shortcuts
themselves (report upstream to Apple), and anything requiring an already-compromised Mac.

## How we handle security internally

Most hardening lands openly as normal issues and PRs (CI runs the test suite on every PR, and
Dependabot watches our GitHub Actions). Genuinely sensitive, high-severity findings go through
the private advisory process above so a fix is available before any public disclosure.
