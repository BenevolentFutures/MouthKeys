# MouthKeys and FluidVoice.

MouthKeys is a fork of [FluidVoice](https://github.com/altic-dev/FluidVoice) by altic-dev, taken on 2026-08-15 at upstream [`d62adc9`][base]. FluidVoice did the hard part: the speech pipeline, the model integrations, hotkeys, typing into other apps, settings and model downloads. this page covers what we changed, what we left out, how to move over, and how we keep following their work.

## why we forked.

we dictate into coding agents all day, and we needed one thing done perfectly: every word lands where we were typing. FluidVoice was growing in many directions at once: an AI model of its own, analytics, its own updater, connections back to its servers. we wanted the engine without the rest, so we cut MouthKeys down to the job and spent the time on what matters to us: delivery that never drops a word, a faster stop, and an interface that stays quiet until you reach for it.

## what's different.

- **open source, all of it.** FluidVoice describes Fluid Intelligence, its AI layer, as "a separate, privately maintained local AI runtime", kept private "for now" ([its README][fv-readme]). MouthKeys removes it, its settings and its model download. [#3]
- **no analytics.** FluidVoice sends one anonymous activity signal per day, in weekly batches, and detailed anonymous analytics unless you turn them off ([its README][fv-readme]). MouthKeys has neither: analytics are hard-wired off and the keys are blank. [`0e2948a`][0e2948a], [#3]
- **nothing sent to FluidVoice's servers.** Feedback opens a draft GitHub issue in your browser instead of posting to altic.dev. the transcript reports, the changelog feed and the updater are gone. [#3]
- **paste you can trust.** a paste that fails in a way the app can detect shows a card and puts the text on your clipboard; your own clipboard comes back afterwards; back-to-back dictations queue instead of dropping. [#4], [`8ab26a8`][8ab26a8]
- **a faster stop.** in a headless benchmark with a 13,600-entry history, stop-path work outside the model fell from a 145 ms median at the fork to 4 ms. a stalled model no longer loses the recording. [#9], [#10]
- **terminals as first-class.** FluidVoice forces Reliable Paste for Ghostty; MouthKeys adds [c11](https://github.com/Stage-11-Agentics/c11). FluidVoice blocks Spoken Send in terminals; MouthKeys sends in every app, only into the pane or field you stopped in. [`8ed75b9`][8ed75b9], [#7], [#8]
- **a quiet interface.** one visual language, Datasheet Mono, across the overlay, history, cards, menu bar and icon. [#17]

some of what MouthKeys has is FluidVoice's later work, ported by hand. [UPSTREAM.md](../UPSTREAM.md) credits each commit.

## what's left out.

MouthKeys is narrower on purpose.

- **Fluid Intelligence**, FluidVoice's private AI layer. [#3]
- **support for AI cleanup.** the provider-based cleanup FluidVoice shipped is still in the app, under Advanced in the sidebar. we don't use it, test it or support it, and setup never asks about it. if you want it, it's yours: point your coding agent at the code and fix or change it to your heart's content.
- **the built-in updater.** it updates to FluidVoice, which would replace MouthKeys, so it is off. you update by downloading the new release. [`19202c1`][19202c1], [#3]

if you want FluidVoice's AI features, FluidVoice is the app for that.

## coming from FluidVoice.

stock FluidVoice and the earliest builds of this fork share the bundle ID `com.FluidApp.app`. if you have used either on this Mac, MouthKeys copies their settings, dictionary and history once, on its first launch, and never changes the originals. after that the two apps keep separate data and can run side by side. macOS does not carry permissions over between apps, so you grant Microphone and Accessibility again.

## following FluidVoice.

we follow FluidVoice's work and port the fixes that fit here by hand, crediting each in the commit. we never merge upstream: our typing, audio and overlay code has diverged where their fixes land. what we took, what we skipped, and why: [UPSTREAM.md](../UPSTREAM.md).

if a fix you make here also applies to FluidVoice, please send it to them too. FluidVoice by altic-dev and its contributors built nearly all of this. if MouthKeys is useful to you, please [sponsor altic-dev](https://github.com/sponsors/altic-dev).

[base]: https://github.com/altic-dev/FluidVoice/commit/d62adc9ac35467f9933fda689111514545466a2d
[fv-readme]: https://github.com/altic-dev/FluidVoice#readme
[0e2948a]: https://github.com/BenevolentFutures/MouthKeys/commit/0e2948ac
[19202c1]: https://github.com/BenevolentFutures/MouthKeys/commit/19202c1a
[8ed75b9]: https://github.com/BenevolentFutures/MouthKeys/commit/8ed75b9a
[8ab26a8]: https://github.com/BenevolentFutures/MouthKeys/commit/8ab26a8f
[#3]: https://github.com/BenevolentFutures/MouthKeys/pull/3
[#4]: https://github.com/BenevolentFutures/MouthKeys/pull/4
[#7]: https://github.com/BenevolentFutures/MouthKeys/pull/7
[#8]: https://github.com/BenevolentFutures/MouthKeys/pull/8
[#9]: https://github.com/BenevolentFutures/MouthKeys/pull/9
[#10]: https://github.com/BenevolentFutures/MouthKeys/pull/10
[#17]: https://github.com/BenevolentFutures/MouthKeys/pull/17
