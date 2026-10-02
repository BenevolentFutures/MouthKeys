# MouthKeys app: Signal

**Status: direction accepted by Atin, round 2 (2026-10-02).** Round 1: "Holy shit. This looks sick." All five round 1 decisions accepted. Round 2 adds the grin as a literal logo. No Swift was touched.

Prototype: [`index.html`](index.html), self-contained (double-click, or `./serve.sh` for Safari, which renders SF Mono). Screenshots of every screen in both themes: [`shots/`](shots/), regenerated with `python3 shoot.py` (headless WebKit, nothing on screen).

Keys: **T** toggles dark and light (the page follows `prefers-color-scheme` until you press it), **O** opens the first-run wizard (arrows step through it), **1–0** jump to the ten sidebar screens, **Esc** closes menus. The menu bar mark (top right) opens the status menu. Press **Start Recording** on Getting Started to drive the overlay reference; every live grin opens its jaw with the voice.

## Thesis, applied to the window

The overlay is an engineering drawing of an instrument. The window is the same drawing set: the sidebar is the margin with its zone index, each screen is a sheet with a title block, each section a zone label with a rule running to the edge, each settings group a ruled table. Square solid surfaces, 1 px rules, no radius, no gradient, no blur except the one float shadow under windows (the overlay's `float-shadow`). Mono uppercase for every label, count and number; SF Pro for anything read as prose. International orange only for something live or actionable right now: the record button, a download in progress, a step that needs you, a NOT PASTED marker, a destructive confirm. State is otherwise carried by inversion and by words with a square: filled ink (done), filled orange (live or needs you), outline (absent).

Tokens are DESIGN.md §2 copied verbatim into CSS variables. Five window-only tokens are added and named in the CSS: `desk` (stage only), `rule` (= edge), `rule-soft` (row hairlines), `sidebar` and `field` (one step below surface).

## The bracket rule

Brackets are the overlay's: four L marks outside the corners, 1.5 pt stroke on a 1 pt surface halo, never orange, 60 ms fade, no layout effect. The window adds one tier at rest:

1. **At rest:** the screen's primary action, and the chosen card in a choice set. At most one primary per panel (Getting Started's next setup step, the playground's record button, Copy in a history entry, the wizard's Continue). At-rest brackets draw at 62% and go to full on hover, so hover still answers the pointer.
2. **On hover:** every other clickable control: secondary and text buttons, segmented controls, pickers, toggles (around the switch only), hotkey wells, fields, tags, overlay chips.
3. **Never:** rows. Sidebar, tables, lists, menus, titlebar cells and the settings zone strip invert instead, as the overlay's history card does.

A screen with no single action (Settings saves as you go) has no at-rest bracket. That is the point: a bracket at rest means "this is the move".

## Layout grid

- Window 1120 × 760 in the prototype (the app's default is 1000 × 700, minimum 800 × 500; everything reflows). Titlebar 40, sidebar 240 (inside the app's 220–300).
- Content: 40 pt side padding, 880 max width, 8 pt rhythm. Title block: mono placard, 28/32 semibold title, 14/20 lede, rule. Sections 34 apart.
- Settings rows: 60 pt minimum, label 14/19 medium, help 13/18, control right-aligned. Dependent rows indent 22 with a drawn leader.
- Type floor: 10 pt mono uppercase, 13 pt prose. Every number is mono, so tabular by construction. Toggles (74 wide with a reserved ON/OFF word), segments (fixed cell widths) and readouts (fixed character boxes) never change size.

## Screens

Main window, sidebar order and names as `ContentView.swift`:

| # | Section | Screen | What changed |
|---|---|---|---|
| 01 | Configure | Settings | One sheet, ten lettered zones (App, Hotkeys, Dictation, History, Format, Alerts, Audio, Overlay, Backup, Debug) with a sticky zone strip. Microphone permission folds into Audio. |
| 02 | Configure | Voice Engine | Preview panel with a spec strip (size, languages, speed and accuracy as 10-cell meters), then the model table. Filler words as tags. |
| 03 | Configure | Custom Dictionary | Teach Words (voice / manual) with a 3-cell readiness meter; the dictionary, spoken formatting and custom words shown inline as tables instead of popovers. |
| 04 | Use | Command Mode | Not-ready banner (it needs an AI Enhancement provider), chat with an orange-ruled confirm panel; Empty / Sample toggle in the prototype. |
| 05 | Use | File Transcription | Drop zone, then file options, progress, speaker-labelled result; recent table. Header now matches the sidebar ("File Transcription", was "Meeting Transcription"). |
| 06 | Activity | History | Full-bleed list and detail: overlay-style index column, NOT PASTED marker, a title-block strip of facts, large reading text. Empty state included. |
| 07 | Activity | Stats | Four KPI cells, words-per-day bars (today in orange), milestone grid, insights and records tables. |
| 08 | Advanced | AI Enhancement | Alone under Advanced, opening with the unsupported note verbatim. Providers and Advanced Prompts as tabs. |
| 09 | Help | Getting Started | Quick Setup as four numbered steps, the playground, the round 6 overlay pill live beside it, How to Use. |
| 10 | Help | Feedback | Text, version toggle, Open GitHub Issue; the FluidVoice credit. |

Also: the first-run wizard (Welcome, Language, Voice Engine, Enable Access, Try MouthKeys, ending in Finish Setup) as the window's first state with a step rail, the status menu with its microphone submenu, the titlebar (Today, Theme, Report) and a hotkey capture state.

## The grin as a logo (round 2)

Atin: "keeping this engineering vibe, but leaning into the idea of MouthKeys as a literal logo". The grin is rebuilt as inline SVG from the shipping geometry, number for number: `scripts/make_app_icon.swift` (64-unit grid, seven keycap teeth a jaw on a 6.4 pitch, the 3-unit bite, the smile, the gold tooth at lower index 4) and `SignalMenuBarMark.swift` (the 22 × 16 mark). Nothing is drawn by eye. Detail follows the pixel count exactly as the icon does: at 4.6 px a unit or more it is the 256 px drawing (0.3-unit chamfers at 0.55), from 2.3 the 128 px drawing (0.6 at 0.8), below that the five-tooth small master.

**Theming.** Teeth fill `ink`, chamfers stroke `surface`. In dark that is exactly the app icon (white keycaps on `#111214`). In light it prints: ink keycaps with paper-white chamfers on white. The gold tooth is `#FF4F1F` in both. No tile inside the app: the window's surface already is the tile in dark, and a black square on paper would read as a sticker, not a drawing.

Where it appears, prominent on core screens and nowhere else:

1. **Corner stamp, bottom-left of the sidebar, always.** The drawing's title block: the grin (128 px drawing, live jaw) beside the MOUTHKEYS wordmark and revision, over the engine / input / hotkey cells.
2. **Getting Started, Fig. 1.** The grin as a dimensioned engineering drawing on the sheet grid: teeth numbered 01–14, overall width and height dimensions, a centre line through the bite, callouts for the keycap plan view, the bite and smile, and TOOTH 12 (the gold tooth), with a DWG / REV / SHEET title strip.
3. **Wizard, Welcome step.** The same drawing as the first thing a new user sees, above "Just speak."
4. **Menu bar.** The fake menu bar shows the real menu bar mark (grin, status square, hover bracket); the menu header carries the small-master grin beside MOUTHKEYS.
5. **Empty states** (History, Custom Dictionary). A quiet 1 px outline grin, gold tooth outlined in orange.

**Live.** While recording, every live grin's lower jaw drops with the voice at 8 Hz in the menu bar mark's steps (closed, 1.5 units, 3 units; the menu bar mark itself drops 1 or 2 pt), and Fig. 1's callout reads TOOTH 12 · LIVE instead of GOLD. The orange tooth is the one colour, so it doubles as the live mark.

## Native mapping

| Component | SwiftUI / AppKit | Cost |
|---|---|---|
| Bracket (`.tk`) | The overlay's `Bracket: Shape`, reused. A `SignalBracketed` modifier with `rest: Bool`; opacity 0.62 at rest, 1 on `.onHover`. | Small: exists |
| Window | `NavigationSplitView` keeps its structure; `.windowStyle(.hiddenTitleBar)` plus our own 40 pt title strip; sidebar `List` replaced by a `ScrollView` of `SignalNavRow` (a `Button` with an inverted selected style). Traffic lights stay the system's. | Medium |
| Title block, section rule | `SignalSheetHeader` and `SignalSection` views: a mono `Text` placard, title, and a `Rectangle().frame(height: 1)`. | Small |
| Settings row | `SignalRow(label:help:) { control }`, an `HStack` with a 1 px bottom rule; `.indent` adds the leader `Path`. Replaces `Form`/`GroupBox`. | Small |
| Zone strip | `ScrollViewReader` + a pinned header (`LazyVStack(pinnedViews: .sectionHeaders)`); cells `scrollTo` their zone. | Small |
| Toggle | A custom `ToggleStyle`: 40 × 20 `Rectangle`, 12 pt square knob, fixed-width mono ON/OFF. | Small |
| Segmented | A custom `Picker` rendering: `HStack(spacing: 0)` of fixed-width cells, selected cell `inv-bg`. Not `.pickerStyle(.segmented)`, which forces radius. | Small |
| Picker | `Menu` with a custom label (field box plus chevron); `NSMenu` styling stays the system's, header rows as disabled mono items, as the status menu does today. | Small |
| Slider | Custom: a `GeometryReader` track, `DragGesture` thumb, graticule `Canvas`, fixed-width mono readout. | Medium |
| Hotkey well | Wraps the existing shortcut recorder; cap views are mono `Text` in a 1 px box; capture state swaps to the orange square and "Press shortcut…". | Small |
| Tables (models, dictionary, devices, history) | `LazyVStack` of row `Button`s with hover and selection inversion; headers are mono rows. Not `Table`, whose chrome cannot be squared. | Medium |
| Meters, readiness, milestones | Plain `HStack`s of `Rectangle`s. | Small |
| Stats chart | Swift Charts `BarMark` with square ends, no gradient, today in `accent`; or a `Canvas`. | Small |
| Empty state | A `Canvas` grid background with a ruled card on top. | Small |
| Overlay reference in the playground | Host the real `SignalOverlay` view inline, driven by the playground recording. | Small |
| Grin logo | One `SignalGrin: View` drawing the `make_app_icon.swift` geometry in a `Canvas` (teeth `Rectangle`s, keycap `Path`s), detail picked from the rendered pixel width, the lower jaw an offset driven by the same `listeningJaw` value as the menu bar mark. Fig. 1 is that view plus annotation `Path`s and mono `Text` in an overlay. | Medium |
| Wizard | `OnboardingFlowView` keeps its steps; the backdrop glow and cards are replaced by the step rail, a ruled content area and the ruled footer. | Medium |

## Decisions on record

1. **Accent Color picker removed, final** (Atin, round 2). Signal has one colour. Anyone who wants another forks MouthKeys and has their own agent change it, the same stance as AI Enhancement.
2. Edit Mode and Command Mode guidance dropped from Getting Started: both need an AI provider, which setup never asks for. Command Mode keeps its own screen with a not-ready banner. (Atin, round 2)
3. Custom Dictionary popovers became inline tables. (Atin, round 2)
4. History detail shows delivery (Pasted / NOT PASTED) to match the overlay card; AI Processed moves to the details line. The detail actions are the app's own: Copy, Audio, Export Pair, Delete (icon). (Atin, round 2)
5. The wizard is the window's first state with a step rail, not a cinematic backdrop. (Atin, round 2)
6. Round 2, ours, not yet reviewed: the grin is tileless and themed (print in light); the stamp lives bottom-left; Fig. 1 on Getting Started and the Welcome step; outline grins only in the two empty states.

## Unsure

- Command Mode's honest state for a straight-dictation user is "not ready". The sample chat is shown so the confirm panel can be judged.
- Sound cue names (Liquid SFX 0–4) and the AI Prompt picker are kept as they are.
- Stats figures, the app version string and the file-transcription transcript are invented for realism.
