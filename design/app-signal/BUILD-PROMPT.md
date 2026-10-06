# Build prompt: MouthKeys Datasheet Mono window

Paste everything below the line into a fresh seat (Claude Code on Opus, or Codex) opened in `~/Projects/MouthKeys` inside c11. It runs as the orchestrator: it builds phases 0 and 1 itself, then fans out lanes. Before pasting, check that the "Open with Atin" items in `BUILDPLAN.md` still stand, and that `design/app-signal` is pushed (the lanes branch from it).

---

You are building the approved Datasheet Mono redesign of the MouthKeys main window: a pure restyle of the SwiftUI app to match an HTML prototype, one to one, with no behavior change. You are the orchestrator. This run is loopy: implement, validate, iterate, report.

**Read first, in order:**
1. `CLAUDE.md`. Its rules bind every agent you launch: never touch `/Applications/MouthKeys.app` or its data, never install or release, keep the XCTest host invisible and silent, full suites on Atlas.
2. `design/visual-language/DESIGN.md`, the locked Datasheet Mono tokens.
3. `design/app-signal/DIRECTION.md`: thesis, bracket rule, layout grid, screen table, native mapping, decisions on record.
4. `design/app-signal/BUILDPLAN.md`: ground rules, where things live, phases, validation loop, parity checklist, risks. It is the contract; follow it.
5. The prototype itself. Serve it with `PORT=8767 design/app-signal/serve.sh` (8766 is often held by the visual-language prototypes server, which serves a different folder and returns 404 here) and open it in a c11 browser tab. Keys: T theme, O wizard, S setup state, 0 to 9 screens. Screenshots of every screen in both themes are in `design/app-signal/shots/`.

**Branching.** Start from `origin/main`. Work on `feature/signal-window` and one branch per lane off it, or off `main` after phases 0 and 1 merge. Bring `design/app-signal/` into the first PR so the reference lives in the repo. PRs go to `--repo BenevolentFutures/MouthKeys --base main`.

**Sequence.**
1. Phase 0 (foundations) and phase 1 (window chrome), yourself, in order. Each is one PR: fresh-context review, full suite on Atlas, merge.
2. Then launch lanes 2 to 6 in parallel, each in its own worktree and c11 tab (load the `c11` skill; name each tab). Give every lane: its phase section of `BUILDPLAN.md`, the files it owns, the ground rules, the validation loop and the parity checklist duty. Lanes touch only their own `detailContent` case in `ContentView.swift`. Lane A (Settings) writes `design/app-signal/PARITY.md` first; the other lanes add their rows to it.
3. Each lane opens a PR. You review it with a fresh-context agent, run the full suite on Atlas, compare its offscreen renders with `shots/`, and merge. Split polish into follow-up PRs rather than holding a merge.
4. Last: one Debug-build walkthrough of every screen in both themes, the wizard and the status menu, against the prototype. Fix what differs. Add the real-path checks to `docs/INSTALL-CHECKLIST.md`.

**Hard rules.**
- Nothing disappears except the Accent Color picker. States the prototype never drew still ship, styled in Datasheet Mono (BUILDPLAN rule 2: permission recovery, conflicting copies, Relaunch, recording-disabled settings, model download states, the regional filler offer, the overlay mic picker).
- The live overlay, the menu bar mark and text delivery stay untouched. Delivery into c11 and Ghostty must never regress.
- Tokens only from `SignalTheme`; reuse the existing `Signal*` primitives; no layout jumps.
- One agent at a time drives the screen with a Debug build, its shortcuts first moved off Atin's keys (CLAUDE.md, Validate). Confine it to a verified display, quit the Debug build when done, and never touch the installed app. Anything that could quit the installed app waits for an idle dictation log.
- Heavy work goes to Atlas: full suites, cold builds, batch renders. Hyperion runs only incremental builds and single test suites.

**Reporting.** Post a short status at every merge: which phases and lanes are merged, which are in flight, what is blocked. Open every report with "Needs you:" and numbered questions. Finish with: merged PRs, the walkthrough result, follow-ups, and the install handoff for Atin (the Developer ID path in `docs/INSTALL-CHECKLIST.md`; he installs).
