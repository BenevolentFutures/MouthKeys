# Build prompt: MouthKeys Datasheet Mono window

**Who runs it** (Atin, 2026-10-07, seats changed 2026-10-08): Codex on Sol (`gpt-6.1-sol`) at high effort, standard speed, orchestrates; Codex seats on Luna (`gpt-6-luna`) at max effort in fast mode do all the implementation. Atin named fast mode for the Luna seats; nothing else runs fast. Ready to start: every open question was answered on 2026-10-07 (`BUILDPLAN.md`, "Decided with Atin") and `design/app-signal` is pushed.

Launch the orchestrator from any c11 shell. Use the newest Sol in Codex `/model` if one has shipped since (never an older one):

```bash
c11 launch-agent --type codex --model gpt-6.1-sol --effort high \
  --cwd ~/Projects/MouthKeys --title "MouthKeys build" \
  --prompt "Read /Users/atin/Projects/MouthKeys-worktrees/app-signal/design/app-signal/BUILD-PROMPT.md and follow everything below its line."
```

Then read the new tab's status line: it must say Sol at high with no "fast" (`~/.claude/references/launching-agents.md`).

---

You are orchestrating the approved Datasheet Mono redesign of the MouthKeys main window: a pure restyle of the SwiftUI app to match an HTML prototype, one to one, with no behavior change. You run on Sol. You brief, review, gate and merge; Luna seats write the product code, every phase and every lane. This run is loopy: implement, validate, iterate, report.

**Read first, in order:**
1. `CLAUDE.md`. Its rules bind every agent you launch: never touch `/Applications/MouthKeys.app` or its data, never install or release, keep the XCTest host invisible and silent, full suites on Atlas.
2. `design/visual-language/DESIGN.md`, the locked Datasheet Mono tokens.
3. `design/app-signal/DIRECTION.md`: thesis, bracket rule, layout grid, screen table, native mapping, decisions on record.
4. `design/app-signal/BUILDPLAN.md`: ground rules, where things live, phases, validation loop, parity checklist, risks, and the decisions Atin settled on 2026-10-07. It is the contract; follow it, and don't reopen a settled decision.
5. The prototype itself. Serve it with `PORT=8767 design/app-signal/serve.sh` (8766 is often held by the visual-language prototypes server, which serves a different folder and returns 404 here) and open it in a c11 browser tab. Keys: T theme, O wizard, S setup state, 0 to 9 screens (prototype navigation only; the app gets no screen-jump shortcuts). Screenshots of every screen in both themes are in `design/app-signal/shots/`.

The design files live on `origin/design/app-signal`, not on `main`; read them there (`git show origin/design/app-signal:<path>`, or the worktree at `~/Projects/MouthKeys-worktrees/app-signal`).

**Branching.** Start from `origin/main`. Work on `feature/datasheet-window` and one branch per lane off it, or off `main` after phases 0 and 1 merge. Bring `design/app-signal/` into the first PR so the reference lives in the repo. PRs go to `--repo BenevolentFutures/MouthKeys --base main`.

**Seats.** Load the `c11` skill first; set your own `mailbox.address` so seats can report to you.
- **Implementers: Luna, fast, max.** One Codex seat per phase or lane, launched from the saved c11 config: `c11 config launch "Luna Fast Max" --workspace <yours> --cwd <its worktree> --prompt-file <brief> --json`. That config runs `codex --yolo -c service_tier=priority --model gpt-6-luna -c model_reasoning_effort=max`, so fast mode applies to that seat alone. After each launch, read the seat's status line: it must say `GPT-6-Luna max fast` (checked 2026-10-08; the startup warning that `-c` overrides need embedded mode is expected). Never send `/fast` or `/ultrafast` to any seat, and never change `service_tier` in `~/.codex/config.toml`: that file is shared, and fast there arms every new Codex session on the machine, you included. `config launch` takes no `--title`; the brief tells the seat to name its own panel (2 to 4 words, lane first). Each seat gets its own git worktree under `~/Projects/MouthKeys-worktrees/`, never the main checkout.
- **Briefs.** Write each brief to a file; never put prose in a shell argument. It carries the seat's phase section of `BUILDPLAN.md`, the files it owns, the ground rules, the validation loop, its parity checklist duty, the hard rules below, and how to report: `c11 mailbox send` to you when its PR opens, when it is blocked, and when it is done. Tell it to load the `c11` skill and run `c11 conversation capture-runtime` first, as the skill asks of every Codex seat.
- **Reviews.** Every PR gets a fresh-context review by Astra (`gpt-6-astra`, xhigh, standard speed: `c11 launch-agent --type codex --model gpt-6-astra --effort xhigh`). Findings go back to the owning Luna seat to fix.
- **Re-dispatch.** A Luna seat that fails two review rounds, or repeats the same failed assumption, hands its lane to Sol (`gpt-6.1-sol`, high) at its next clean pushed boundary. Say so in the next status.
- **Limits.** Run Codex to its limit. If a seat hits a limit, stop it at a clean pushed boundary, move the lane to Grok (`c11 launch-agent --type grok --model grok-4.7`, its own worktree, since Grok's permission modes do not stop file writes), and report it.

**Sequence.**
1. Phase 0 (foundations), then phase 1 (window chrome): one Luna seat each, in order; phase 1 starts after phase 0 merges. Each is one PR: fresh-context review, full suite on Atlas, merge.
2. Then lanes 2 to 6 in parallel, one Luna seat each. Lanes touch only their own `detailContent` case in `ContentView.swift`. Lane A (Settings) writes `design/app-signal/PARITY.md` first; the other lanes add their rows to it.
3. Each lane opens a PR. You get it reviewed, run the full suite on Atlas, compare its offscreen renders with `shots/`, and merge. Split polish into follow-up PRs rather than holding a merge.
4. Last: one Debug-build walkthrough of every screen in both themes, the wizard and the status menu, against the prototype. Hand what differs to Luna seats as fix PRs. Add the real-path checks to `docs/INSTALL-CHECKLIST.md`.

**Hard rules.**
- Nothing disappears except the Accent Color picker. Where `main` changed after the prototype, `main` wins: PR #57 removed "Allow in c11" (the prototype still draws it; don't build it) and added Q for Question Mark. States and controls the prototype never drew still ship, styled in Datasheet Mono (BUILDPLAN rule 2: permission recovery, conflicting copies, Relaunch, recording-disabled settings, model download states, the regional filler offer, the overlay mic picker, Q for Question Mark).
- The live overlay, the menu bar mark and text delivery stay untouched. Delivery into c11 and Ghostty must never regress.
- Tokens only from `DatasheetTheme` (`SignalTheme` until phase 0's rename); reuse the existing primitives; no layout jumps.
- One agent at a time drives the screen with a Debug build; you hand out that turn. Its shortcuts are first moved off Atin's keys (CLAUDE.md, Validate). Confine it to a verified display, quit the Debug build when done, and never touch the installed app. Anything that could quit the installed app waits for an idle dictation log.
- Heavy work goes to Atlas: full suites, cold builds, batch renders. Hyperion runs only incremental builds and single test suites.
- Fast mode only where Atin named it: the Luna seats, through the saved config. You, Astra and any fallback seat run at standard speed.

**Reporting.** Post a short status at every merge: which phases and lanes are merged, which are in flight and on which seat, what is blocked. Open every report with "Needs you:" and numbered questions. Finish with: merged PRs, the walkthrough result, follow-ups, and the install handoff for Atin (the Developer ID path in `docs/INSTALL-CHECKLIST.md`; he installs).
