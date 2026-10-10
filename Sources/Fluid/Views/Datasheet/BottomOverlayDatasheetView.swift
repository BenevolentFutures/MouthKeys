import AppKit
import SwiftUI

// MARK: - Bottom Overlay SwiftUI View (Datasheet)

/// The recording overlay in the Datasheet language (DESIGN.md §4, §9): the pill between two rails of
/// chips, History / Copy on the left and Cancel / Reprocess on the right; Spoken Send lives in the
/// trace row (§15). The window keeps a transparent margin around the content (6 pt, 8 at the
/// bottom) so the selection brackets outside the boxes are never clipped; that margin paints
/// nothing, so clicks there reach the app beneath.
struct BottomOverlayView: View {
    @ObservedObject private var contentState = NotchContentState.shared
    @ObservedObject private var model = DatasheetOverlayModel.shared
    @ObservedObject private var appServices = AppServices.shared
    @ObservedObject private var activeAppMonitor = ActiveAppMonitor.shared
    @ObservedObject private var historyPresence = TranscriptionHistoryStore.shared.presence
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var spokenSend = SpokenSendController.shared
    @ObservedObject private var historyCard = BottomOverlayHistoryMenuController.shared
    @ObservedObject private var microphoneCard = BottomOverlayMicrophonePickerController.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The pointer is over the pill itself (not the rails, their gutter or the empty chip slot):
    /// the only place a click cancels a pending Return, so the only place its bracket shows.
    @State private var isHoveringPill = false
    @State private var hoveredChips: Set<String> = []
    @State private var isCopyConfirming = false
    @State private var copyConfirmationID = 0
    /// Where the History chip is on screen, for the card's anchor. A reference, not view state:
    /// the anchor reader reports it during view updates, which must not invalidate the view.
    @State private var historyChipAnchor = DatasheetChipAnchor()
    /// Where the mic label is on screen, for the microphone card (the card's controller owns it).
    private var micLabelAnchor: DatasheetChipAnchor {
        BottomOverlayMicrophonePickerController.shared.labelAnchor
    }
    /// Where the overlay's visible content (the pill between its rails) is on screen: the history
    /// card centres on it.
    @State private var overlayAnchor = DatasheetOverlayAnchor()
    @State private var lastResolvedAppIcon: NSImage?
    @State private var dragStartMouseLocation: NSPoint?
    @State private var dragStartWindowOrigin: NSPoint?

    /// The overlay panel's floating shadow, which the pill reports its box to. Only the overlay's
    /// own panel passes it; a render or another host reports nowhere.
    private let floatShadow: DatasheetFloatShadow.State?
    /// The overlay panel's click targets, for its AppKit double-click (DatasheetClickTargets).
    private let clickTargets: DatasheetClickTargets?

    init(floatShadow: DatasheetFloatShadow.State? = nil, clickTargets: DatasheetClickTargets? = nil) {
        self.floatShadow = floatShadow
        self.clickTargets = clickTargets
    }

    /// What the pill shows, from the controller's phase and the shared flags.
    enum Display: Equatable {
        case listening
        case stopped
        case transcribing
        case delivered(DatasheetDelivery)
        /// The AI-enhancement failure row (provisional).
        case notice
        /// A notice row (DESIGN.md §15): "Speech recognition is back".
        case noticeRow(DatasheetNotice)
        case idle
    }

    var display: Display {
        Self.display(contentState: self.contentState, model: self.model)
    }

    static func display(contentState: NotchContentState, model: DatasheetOverlayModel) -> Display {
        if contentState.isProcessing { return .transcribing }
        if contentState.isAIProcessingFailureVisible { return .notice }
        switch model.phase {
        case .idle: return .idle
        case .listening: return .listening
        case .stopped: return .stopped
        case .transcribing: return .transcribing
        case let .delivered(delivery): return .delivered(delivery)
        case let .notice(notice): return .noticeRow(notice)
        }
    }

    private var geometry: DatasheetOverlayGeometry {
        DatasheetOverlayGeometry.forSize(self.settings.overlaySize)
    }

    /// On screen, not fading out: the overlay takes clicks only then.
    private var isInteractive: Bool {
        self.contentState.isBottomOverlayPresented && !self.contentState.isBottomOverlayDismissing && !self.model.isFading
    }

    // MARK: Chips

    enum ChipRole {
        /// History: live whenever the overlay is, except during the delivered hold.
        case history
        /// Cancel: always live. While recording it cancels the dictation; after the stop it first
        /// drops a pending Return (while SEND shows), otherwise it cancels the paste and dismisses
        /// the pill (the text still goes to History). A stuck transcription can always be closed.
        case cancel
        /// Copy and Reprocess: live only while listening or on a notice; dimmed while transcribing.
        case historyAction
    }

    private var hasHistory: Bool {
        self.historyPresence.hasEntries
    }

    /// Inert: the chip looks at rest but acts on nothing. During the delivered hold no chip may
    /// re-fire a paste or copy; Copy and Reprocess wait until the final pass is done.
    static func isChipInert(_ role: ChipRole, display: Display) -> Bool {
        switch display {
        case .delivered, .idle: return true
        case .stopped: return role == .historyAction
        case .transcribing, .listening, .notice, .noticeRow: return false
        }
    }

    /// Disabled (dimmed): Copy and Reprocess without history, and while transcribing.
    static func isChipEnabled(_ role: ChipRole, display: Display, hasHistory: Bool) -> Bool {
        switch role {
        case .history, .cancel: return true
        case .historyAction: return hasHistory && display != .transcribing
        }
    }

    private func isInert(_ role: ChipRole) -> Bool {
        Self.isChipInert(role, display: self.display)
    }

    private func isEnabled(_ role: ChipRole) -> Bool {
        Self.isChipEnabled(role, display: self.display, hasHistory: self.hasHistory)
    }

    private func chipHover(_ id: String) -> (Bool) -> Void {
        { hovering in
            if hovering { self.hoveredChips.insert(id) } else { self.hoveredChips.remove(id) }
        }
    }

    /// Belt and braces with allowsHitTesting: a hidden overlay's chip must never act.
    private func perform(_ action: () -> Void) {
        guard self.isInteractive else { return }
        action()
    }

    private var historyChip: some View {
        DatasheetChip(
            systemName: "clock.arrow.circlepath",
            help: self.hasHistory ? "Recent Dictations" : "No saved dictation history available",
            isEnabled: self.hasHistory,
            isInert: self.isInert(.history),
            isLatched: self.historyCard.isOpen,
            isHoverForced: self.model.inspectionHover == "history",
            onHoverChanged: self.chipHover("history")
        ) {
            self.perform {
                BottomOverlayHistoryMenuController.shared.updateAnchor(
                    selectorFrameInScreen: self.historyChipAnchor.frameInScreen,
                    overlayFrameInScreen: self.overlayAnchor.frameInScreen(window: self.historyChipAnchor.window),
                    parentWindow: self.historyChipAnchor.window,
                    maxWidth: DatasheetTheme.Metrics.historyWidth
                )
                BottomOverlayMicrophonePickerController.shared.hide(reason: "history_opened")
                BottomOverlayHistoryMenuController.shared.toggleFromTap()
            }
        }
        .background(
            PromptSelectorAnchorReader { [historyChipAnchor] frameInScreen, window in
                historyChipAnchor.frameInScreen = frameInScreen
                historyChipAnchor.window = window
            }
            .allowsHitTesting(false)
        )
    }

    private var copyChip: some View {
        DatasheetChip(
            systemName: "doc.on.doc",
            help: self.hasHistory ? "Copy Last Transcription" : "No saved dictation history available",
            isEnabled: self.isEnabled(.historyAction),
            isInert: self.isInert(.historyAction),
            isConfirming: self.isCopyConfirming,
            isHoverForced: self.model.inspectionHover == "copy",
            onHoverChanged: self.chipHover("copy")
        ) {
            self.perform {
                BottomOverlayHistoryMenuController.shared.hide()
                self.contentState.onCopyLastRequested?()
                self.confirmCopy()
            }
        }
    }

    private var cancelChip: some View {
        DatasheetChip(
            systemName: "xmark",
            help: "Cancel Dictation (\(self.settings.cancelRecordingHotkeyShortcut.displayString))",
            isInert: self.isInert(.cancel),
            isHoverForced: self.model.inspectionHover == "cancel",
            onHoverChanged: self.chipHover("cancel")
        ) {
            self.perform {
                BottomOverlayHistoryMenuController.shared.hide()
                // On a notice row the Cancel chip dismisses it (DESIGN.md §15).
                if case .noticeRow = self.display {
                    BottomOverlayWindowController.shared.dismissNotice()
                    return
                }
                if self.display == .notice {
                    self.contentState.clearAIProcessingFailure()
                }
                // After the stop, with no Return left to drop: cancel this dictation's paste and
                // dismiss the pill, however long its transcription is taking.
                if self.display == .stopped || self.display == .transcribing, !self.canCancelSend {
                    self.contentState.onDismissStoppedDictationRequested?()
                    return
                }
                self.contentState.onCancelRequested?()
            }
        }
    }

    private var reprocessChip: some View {
        DatasheetChip(
            systemName: "arrow.clockwise",
            help: self.hasHistory ? "Reprocess Last Dictation" : "No saved dictation history available",
            isEnabled: self.isEnabled(.historyAction),
            isInert: self.isInert(.historyAction),
            isHoverForced: self.model.inspectionHover == "reprocess",
            onHoverChanged: self.chipHover("reprocess")
        ) {
            self.perform {
                BottomOverlayHistoryMenuController.shared.hide()
                // On a notice row the chip is the row's Reprocess: once, and the row gives way.
                if case .noticeRow = self.display {
                    BottomOverlayWindowController.shared.reprocessFromNotice()
                    return
                }
                self.contentState.clearAIProcessingFailure()
                self.contentState.onReprocessLastRequested?()
            }
        }
    }

    private func confirmCopy() {
        self.copyConfirmationID &+= 1
        let id = self.copyConfirmationID
        self.isCopyConfirming = true
        DispatchQueue.main.asyncAfter(deadline: .now() + DatasheetTheme.Motion.copyFeedbackChip) {
            guard self.copyConfirmationID == id else { return }
            self.isCopyConfirming = false
        }
    }

    // MARK: Body

    var body: some View {
        let geometry = self.geometry
        HStack(alignment: .bottom, spacing: DatasheetTheme.Metrics.railGap) {
            DatasheetRail(height: geometry.railHeight) {
                self.historyChip
            } middle: {
                Color.clear
            } bottom: {
                self.copyChip
            }
            self.pill(geometry)
            DatasheetRail(height: geometry.railHeight) {
                self.cancelChip
            } middle: {
                // Reserved. Spoken Send lives in the trace row (DESIGN.md §15), not a fifth chip.
                Color.clear
            } bottom: {
                self.reprocessChip
            }
        }
        .datasheetOverlayAnchor(self.overlayAnchor)
        .onHover { hovering in
            // A notice row's timer waits while the pointer is over the pill or its rails.
            BottomOverlayWindowController.shared.noticeHoverChanged(hovering)
        }
        .padding(DatasheetTheme.Metrics.windowInsets)
        // Whole-surface drag with position memory. Double-click (back to the default anchor) is
        // detected in AppKit by the overlay's hosting view, away from the buttons reported here:
        // a SwiftUI double-tap on this parent made every chip wait ~350 ms before acting.
        .gesture(self.windowDragGesture)
        .onPreferenceChange(DatasheetClickTargetsKey.self) { [clickTargets] rects in
            clickTargets?.rects = rects
        }
        .datasheetPalette()
        // A hiding or hidden overlay must never act on a click meant for the app beneath it.
        .allowsHitTesting(self.isInteractive)
        .modifier(BottomOverlayVisibility(
            isFading: self.model.isFading,
            isPresented: self.contentState.isBottomOverlayPresented,
            reduceMotion: self.reduceMotion
        ))
        .onChange(of: self.display) { _, display in
            switch display {
            case .delivered, .idle:
                BottomOverlayHistoryMenuController.shared.hide()
                BottomOverlayMicrophonePickerController.shared.hide(reason: "dictation_done")
            case .listening, .stopped, .transcribing, .notice, .noticeRow:
                break
            }
        }
        .onChange(of: self.contentState.mode) { _, mode in
            switch mode {
            case .dictation: self.contentState.promptPickerMode = .dictate
            case .edit, .write, .rewrite: self.contentState.promptPickerMode = .edit
            case .command: break
            }
        }
        // A hidden overlay gets no hover-out: forget the hover so no bracket shows at rest next time.
        .onChange(of: self.contentState.isBottomOverlayPresented) { _, presented in
            guard !presented else { return }
            BottomOverlayMicrophonePickerController.shared.hide(reason: "overlay_hidden")
            self.isHoveringPill = false
            self.hoveredChips.removeAll()
        }
        .onAppear {
            self.rememberAppIcon(self.contentState.targetAppIcon ?? self.activeAppMonitor.activeAppIcon)
        }
        .onReceive(self.contentState.$targetAppIcon) { icon in
            self.rememberAppIcon(icon)
        }
    }

    /// The pill's bracket: under the pointer, and only while the pill is clickable as a whole
    /// (SEND shows and a click cancels the Return). Brackets mark only what you can click.
    static func showsPillBracket(isClickable: Bool, isHovered: Bool) -> Bool {
        isClickable && isHovered
    }

    private func pill(_ geometry: DatasheetOverlayGeometry) -> some View {
        let display = self.display
        // Brackets mark only what you can click (DESIGN.md §7, Atin 2026-09-29). The pill is
        // clickable as a whole only while SEND shows and a click cancels the Return.
        let pillBracket = Self.showsPillBracket(
            isClickable: self.canCancelSend || self.model.inspectionPlacard == .send,
            isHovered: (self.isHoveringPill && !self.historyCard.isHovered && self.isInteractive)
                || self.model.inspectionHover == "pill"
        )
        return DatasheetPill(
            geometry: geometry,
            topHeight: geometry.topAreaHeight,
            traceRow: self.traceRow(geometry, display: display),
            foot: DatasheetFootRow(
                icon: self.contentState.targetAppIcon ?? self.activeAppMonitor.activeAppIcon ?? self.lastResolvedAppIcon,
                micText: self.micText,
                counters: self.counterInput(display),
                counterClock: self.model.counterClock,
                placard: self.placard,
                micBattery: self.model.micBattery,
                micPrefix: self.micPrefix,
                onMicTap: self.canPickMicrophone(display) ? { self.toggleMicrophoneCard() } : nil,
                micAnchor: self.micLabelAnchor,
                isMicLatched: self.microphoneCard.isOpen,
                isMicHoverForced: self.model.inspectionHover == "mic"
            ),
            isBracketVisible: pillBracket
        ) {
            self.topArea(geometry, display: display)
        }
        // A click anywhere on the pill while SEND shows cancels the Return (DESIGN.md §15).
        // Simultaneous, so the whole surface's double-click (reset position) and drag still work.
        .simultaneousGesture(TapGesture().onEnded {
            // While SEND shows and the Return can still be dropped (listening, stopped or
            // transcribing, until the stop decides), a click cancels it.
            // A click on the mic label opens the microphone card and never cancels Send. Judged by
            // where the click is, not by hover state, which a hidden label can leave stale.
            guard self.isInteractive, self.canCancelSend,
                  !self.micLabelAnchor.frameInScreen.contains(NSEvent.mouseLocation)
            else { return }
            BottomOverlayWindowController.shared.cancelSpokenSendIfArmed()
        })
        .help(self.canCancelSend ? "Click to cancel Send" : "")
        // Tracked on the pill itself, so the bracket never shows where a click would not cancel.
        .onHover { hovering in
            if hovering != self.isHoveringPill { self.isHoveringPill = hovering }
        }
        .datasheetFloatShadowSource(self.floatShadow)
    }

    @ViewBuilder
    private func topArea(_ geometry: DatasheetOverlayGeometry, display: Display) -> some View {
        switch display {
        case let .delivered(delivery):
            DatasheetDeliveredStatement(delivery: delivery, isCompact: geometry.isCompactTop)
        case .notice:
            DatasheetNoticeRow(
                message: self.contentState.aiProcessingFailureMessage,
                canRetry: self.contentState.canRetryAIProcessingFailure,
                isCompact: geometry.isCompactTop,
                onRetry: {
                    self.perform {
                        self.contentState.clearAIProcessingFailure()
                        self.contentState.onReprocessLastRequested?()
                    }
                },
                onDismiss: {
                    self.perform {
                        self.contentState.clearAIProcessingFailure()
                        NotchOverlayManager.shared.hide()
                    }
                }
            )
        case let .noticeRow(notice):
            DatasheetInlineNotice(
                notice: notice,
                isHoverForced: self.model.inspectionHover,
                onHoverChanged: { id, hovering in self.chipHover(id)(hovering) },
                onReprocess: {
                    self.perform { BottomOverlayWindowController.shared.reprocessFromNotice() }
                },
                onDismiss: {
                    self.perform { BottomOverlayWindowController.shared.dismissNotice() }
                }
            )
        case .listening, .stopped, .transcribing, .idle:
            DatasheetPreview(
                text: DatasheetTextFitting.newestWords(
                    of: self.previewText(display),
                    wasCut: self.contentState.transcriptionText.count > self.contentState.cachedPreviewText.count,
                    font: DatasheetTheme.Typography.preview.nsFont,
                    width: geometry.innerWidth,
                    lines: geometry.previewLines
                ),
                lines: geometry.previewLines,
                height: geometry.topAreaHeight,
                width: geometry.innerWidth,
                isDimmed: display == .transcribing
            )
        }
    }

    /// Spoken Send's countdown is showing: the quiet countdown runs (or its cancel is held) while
    /// the phrase sends in this app.
    private var countdownDrain: DatasheetDrain? {
        guard self.display == .listening, let drain = self.model.sendDrain else { return nil }
        return drain
    }

    private var canCancelSend: Bool {
        self.placard == .send && self.spokenSend.hasPendingReturn
    }

    private var placard: DatasheetPlacard {
        if let placard = self.model.inspectionPlacard { return placard }
        return Self.placard(
            display: self.display,
            model: self.model,
            spokenSend: self.spokenSend,
            spokenSendEnabled: self.settings.spokenSendEnabled,
            mode: self.contentState.mode
        )
    }

    /// The placard the pill shows for `display`. The view draws it; the cancel gate reads it, so
    /// "the pill visibly shows SEND" means exactly what is on screen.
    static func placard(
        display: Display,
        model: DatasheetOverlayModel,
        spokenSend: SpokenSendController,
        spokenSendEnabled: Bool,
        mode: OverlayMode
    ) -> DatasheetPlacard {
        switch display {
        case .listening:
            // A canceled countdown keeps NO SEND while its bar is held (it only exists with Spoken Send).
            if model.sendDrain?.isCanceled == true { return .noSend }
            guard spokenSendEnabled, mode == .dictation else { return .none }
            return DatasheetOverlayModel.placard(indicator: spokenSend.indicator)
        case .stopped, .transcribing, .delivered:
            return model.stopPlacard
        case .notice, .noticeRow, .idle:
            return .none
        }
    }

    private func traceRow(_ geometry: DatasheetOverlayGeometry, display: Display) -> DatasheetTraceRow {
        let drain = self.countdownDrain
        let mark: DatasheetRecordMark
        switch display {
        case .listening: mark = drain == nil ? .recording : .closed
        case .stopped, .transcribing: mark = .closed
        case .delivered, .notice, .noticeRow, .idle: mark = .none
        }
        let timer: DatasheetTimerReadout
        if let drain {
            timer = .countdown(drain)
        } else if display == .listening, self.model.frozenDuration == nil, let start = self.model.recordingStartedAt {
            timer = .running(start)
        } else {
            timer = .frozen(self.model.timerText(at: Date()), dim: false)
        }
        return DatasheetTraceRow(
            geometry: geometry,
            trace: self.model.trace,
            isLive: display == .listening && self.model.trace.isLive,
            isSweeping: display == .transcribing,
            drain: drain,
            staticSweepProgress: self.model.inspectionSweepProgress,
            mark: mark,
            timer: timer
        )
    }

    /// The live counters (DESIGN.md §16, Atin 2026-10-01): the word count from 0 at the foot row's
    /// left end and words per minute at its right end, while the dictation is live, stopped,
    /// transcribing or counting down; hidden where the number already shows (Pasted, Sent, a
    /// card), on a notice, and while the pill is not on screen.
    private func counterInput(_ display: Display) -> DatasheetCounterInput? {
        guard self.contentState.isBottomOverlayPresented else { return nil }
        let model = self.model
        return Self.counterInput(
            display: display,
            countsLiveWords: model.countsLiveWords,
            recordingStartedAt: model.recordingStartedAt,
            frozenDuration: model.frozenDuration,
            frozenWords: model.frozenWordCount,
            live: self.contentState.liveWordCount,
            hasLiveText: self.settings.enableStreamingPreview && self.settings.selectedSpeechModel.supportsStreaming
        )
    }

    /// Nothing without a recording of this session behind the pill (a reprocess, including one
    /// that re-shows the pill), or without live text: the streaming preview off, or a model that
    /// does not stream, where the counts would read 0 for the whole dictation.
    static func counterInput(
        display: Display,
        countsLiveWords: Bool,
        recordingStartedAt: Date?,
        frozenDuration: TimeInterval?,
        frozenWords: Int?,
        live: Int,
        hasLiveText: @autoclosure () -> Bool
    ) -> DatasheetCounterInput? {
        guard countsLiveWords, let start = recordingStartedAt else { return nil }
        switch display {
        case .listening:
            guard frozenDuration == nil, hasLiveText() else { return nil }
            return DatasheetCounterInput(recording: start, words: live, clock: .running(start))
        case .stopped, .transcribing:
            // Only after a real stop: frozen there, the count finishes catching up and WPM settles
            // from the recording's length.
            guard let duration = frozenDuration, hasLiveText() else { return nil }
            return DatasheetCounterInput(recording: start, words: frozenWords ?? live, clock: .frozen(duration))
        case .delivered, .notice, .noticeRow, .idle:
            return nil
        }
    }

    // MARK: Text

    /// The live preview without the status words the stop path writes into it ("Transcribing"):
    /// the hollow square, the frozen timer and the sweep carry that state.
    private var livePreview: String {
        let text = self.contentState.cachedPreviewText
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return DatasheetOverlayModel.statusWords.contains(trimmed) ? "" : trimmed
    }

    private func previewText(_ display: Display) -> String {
        switch display {
        case .listening:
            return self.livePreview
        case .stopped, .transcribing:
            // A streamed AI answer replaces the frozen dictation while it refines.
            let live = self.livePreview
            return live.isEmpty || live == self.model.frozenPreview ? self.model.frozenPreview : live
        case .delivered, .notice, .noticeRow, .idle:
            return ""
        }
    }

    /// The microphone, and (provisional, awaiting round 5) the words that replace the retired
    /// mode tint and model spinner: "EDIT", "COMMAND", "LOADING MODEL".
    private var micText: String {
        let microphone = self.model.microphoneName.trimmingCharacters(in: .whitespacesAndNewlines)
        return self.micPrefix + (microphone.isEmpty ? "Microphone" : microphone)
    }

    /// The words before the microphone ("EDIT · "), so the lapel mic's battery label keeps them.
    private var micPrefix: String {
        var parts: [String] = []
        let asr = self.appServices.asr
        if !asr.isAsrReady, asr.isLoadingModel || asr.isDownloadingModel {
            parts.append("Loading model")
        }
        switch self.contentState.mode {
        case .dictation: break
        case .edit, .write, .rewrite: parts.append("Edit")
        case .command: parts.append("Command")
        }
        return parts.map { $0 + " · " }.joined()
    }

    // MARK: Microphone

    /// The mic label opens the microphone card whenever the overlay takes clicks, except during
    /// the delivered hold (where no control acts). It stays a label there, in the same frame.
    private func canPickMicrophone(_ display: Display) -> Bool {
        switch display {
        case .delivered, .idle: false
        case .listening, .stopped, .transcribing, .notice, .noticeRow: true
        }
    }

    private func toggleMicrophoneCard() {
        self.perform {
            BottomOverlayMicrophonePickerController.shared.toggle(
                labelFrameInScreen: self.micLabelAnchor.frameInScreen,
                overlayFrameInScreen: self.overlayAnchor.frameInScreen(window: self.micLabelAnchor.window),
                parentWindow: self.micLabelAnchor.window
            )
        }
    }

    private func rememberAppIcon(_ icon: NSImage?) {
        guard let icon else { return }
        self.lastResolvedAppIcon = icon
    }

    // MARK: Drag

    /// Moves the panel by tracking the pointer in screen coordinates. The gesture's own
    /// translation is in view space, which shifts as the window moves under the cursor.
    private var windowDragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { _ in
                guard self.isInteractive else { return }
                let mouse = NSEvent.mouseLocation
                if self.dragStartMouseLocation == nil {
                    // The card is placed against the overlay where it was; a moved overlay closes it.
                    BottomOverlayMicrophonePickerController.shared.hide(reason: "overlay_drag")
                    self.dragStartMouseLocation = mouse
                    self.dragStartWindowOrigin = BottomOverlayWindowController.shared.frameOriginForDrag
                }
                guard let startMouse = self.dragStartMouseLocation,
                      let startOrigin = self.dragStartWindowOrigin else { return }
                BottomOverlayWindowController.shared.dragWindow(to: NSPoint(
                    x: startOrigin.x + (mouse.x - startMouse.x),
                    y: startOrigin.y + (mouse.y - startMouse.y)
                ))
            }
            .onEnded { _ in
                let didMove = self.dragStartWindowOrigin != nil
                self.dragStartMouseLocation = nil
                self.dragStartWindowOrigin = nil
                if didMove {
                    BottomOverlayWindowController.shared.commitDraggedPosition()
                }
            }
    }
}

/// The overlay's visible content (the pill between its rails) in its hosting view, top-left
/// origin, converted to the screen when the history card opens. Read through SwiftUI geometry,
/// not an NSView: a platform view behind the rails would draw as a placeholder in the renders.
final class DatasheetOverlayAnchor {
    var frameInContent: CGRect = .zero

    func frameInScreen(window: NSWindow?) -> CGRect {
        guard let window, let content = window.contentView, self.frameInContent.width > 0 else { return .zero }
        var rect = self.frameInContent
        if !content.isFlipped {
            rect.origin.y = content.bounds.height - rect.maxY
        }
        return window.convertToScreen(content.convert(rect, to: nil))
    }
}

extension View {
    func datasheetOverlayAnchor(_ anchor: DatasheetOverlayAnchor) -> some View {
        self.onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            anchor.frameInContent = frame
        }
    }
}

/// A chip's on-screen frame and window, reported by `PromptSelectorAnchorReader`.
final class DatasheetChipAnchor {
    var frameInScreen: CGRect = .zero
    weak var window: NSWindow?
}

/// The overlay's visibility (DESIGN.md §8), shared by the overlay and its floating shadow so the
/// shadow never outlives or precedes the pill: the dismiss fades over 120 ms linear (a cut under
/// reduced motion), and hidden paints nothing at all, at once, whatever the fade's progress (a
/// transparent panel passes clicks through wherever its pixels are clear, from the hide on; not
/// animated, so it never depends on a frame clock; ignoresMouseEvents is never touched).
struct BottomOverlayVisibility: ViewModifier {
    let isFading: Bool
    let isPresented: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(self.isFading ? 0 : 1)
            .animation(
                self.isFading && !self.reduceMotion ? .linear(duration: DatasheetTheme.Motion.dismiss) : nil,
                value: self.isFading
            )
            .opacity(self.isPresented ? 1 : 0)
    }
}

/// The pill's floating shadow (DESIGN.md §6), drawn in its own click-through panel under the
/// overlay's (DatasheetFloatShadow), fading and hiding exactly as the overlay does.
struct BottomOverlayShadowView: View {
    @ObservedObject var state: DatasheetFloatShadow.State
    @ObservedObject private var contentState = NotchContentState.shared
    @ObservedObject private var model = DatasheetOverlayModel.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        DatasheetFloatShadowView(state: self.state)
            .datasheetPalette()
            .modifier(BottomOverlayVisibility(
                isFading: self.model.isFading,
                isPresented: self.contentState.isBottomOverlayPresented,
                reduceMotion: self.reduceMotion
            ))
    }
}
