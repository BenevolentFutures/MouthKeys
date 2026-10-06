import AppKit
import Combine
import CoreAudio
import SwiftUI

// MARK: - Model

/// The microphone card's rows: every input device macOS has right now, in a stable order (by
/// name, as CoreAudio lists them), so picking one never moves a row. Live while the card is open:
/// a device that connects or vanishes appears or goes without reopening.
@MainActor
final class MicrophonePickerModel: ObservableObject {
    static let shared = MicrophonePickerModel()

    struct Row: Identifiable, Equatable {
        let device: AudioDevice.Device
        /// Alive, and not a built-in mic behind a closed lid. A device the user removed from
        /// MouthKeys' order is still pickable: picking it puts it back first.
        let isUsable: Bool

        var id: String {
            self.device.uid
        }

        /// "BUILT-IN", "USB", "BLUETOOTH", "VIRTUAL", ...; empty when CoreAudio does not say.
        var kind: String {
            Self.kind(transportType: self.device.transportType)
        }

        static func kind(transportType: UInt32) -> String {
            switch transportType {
            case kAudioDeviceTransportTypeBuiltIn: "Built-in"
            case kAudioDeviceTransportTypeUSB: "USB"
            case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: "Bluetooth"
            case kAudioDeviceTransportTypeVirtual: "Virtual"
            case kAudioDeviceTransportTypeAggregate, kAudioDeviceTransportTypeAutoAggregate: "Aggregate"
            case kAudioDeviceTransportTypeDisplayPort, kAudioDeviceTransportTypeHDMI: "Display"
            case kAudioDeviceTransportTypeThunderbolt: "Thunderbolt"
            case kAudioDeviceTransportTypeContinuityCaptureWired,
                 kAudioDeviceTransportTypeContinuityCaptureWireless: "iPhone"
            default: ""
            }
        }
    }

    @Published private(set) var rows: [Row] = []
    /// The device capture is confirmed on (first PCM), from the coordinator.
    @Published private(set) var activeUID: String?
    /// Picked, and capture has not confirmed it yet (a mid-dictation switch takes a moment).
    @Published private(set) var pendingUID: String?

    private var isWatching = false
    private var refreshGeneration = 0
    private var deviceListListener: AudioObjectPropertyListenerBlock?
    private var cancellables: Set<AnyCancellable> = []

    private init() {}

    /// Rows from a device list, for the card and its tests.
    nonisolated static func rows(
        from devices: [AudioDevice.Device],
        clamshellClosed: Bool
    ) -> [Row] {
        devices
            .filter { AudioDevice.isPrivateDefaultDeviceAggregate(uid: $0.uid, name: $0.name) == false }
            .map { device in
                Row(
                    device: device,
                    isUsable: device.isAlive &&
                        (clamshellClosed == false || device.isUnavailableWhenClamshellClosed == false)
                )
            }
    }

    /// The mark a row carries: filled for the device capture is on, outlined for one picked and
    /// still switching. A pick that vanished, or that capture has confirmed, is no longer pending.
    nonisolated static func mark(
        for uid: String,
        activeUID: String?,
        pendingUID: String?
    ) -> SignalRecordMark {
        if let pendingUID, pendingUID != activeUID {
            return uid == pendingUID ? .closed : .none
        }
        return uid == activeUID ? .recording : .none
    }

    /// `ready` runs once the rows reflect the devices present now, so the card never opens on
    /// an empty or stale list.
    func startWatching(ready: @escaping () -> Void) {
        guard self.isWatching == false else {
            self.refresh(then: ready)
            return
        }
        self.isWatching = true
        let coordinator = AppServices.shared.microphonePreferenceCoordinator
        self.activeUID = coordinator.confirmedActiveInputUID
        // A pick made while the card was closed, now confirmed, is no longer switching.
        if self.pendingUID == self.activeUID { self.pendingUID = nil }
        coordinator.$confirmedActiveInputUID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] uid in
                guard let self else { return }
                self.activeUID = uid
                if uid != nil, uid == self.pendingUID { self.pendingUID = nil }
            }
            .store(in: &self.cancellables)
        NotificationCenter.default.publisher(for: .inputDeviceAvailabilityDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &self.cancellables)
        NotificationCenter.default.publisher(for: .clamshellStateDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &self.cancellables)
        self.addDeviceListListener()
        self.refresh(then: ready)
    }

    func stopWatching() {
        guard self.isWatching else { return }
        self.isWatching = false
        self.cancellables.removeAll()
        self.removeDeviceListListener()
    }

    func pick(_ row: Row) {
        guard row.isUsable else { return }
        if row.id != self.activeUID { self.pendingUID = row.id }
        AppServices.shared.microphonePreferenceCoordinator.pick(row.device, source: "overlay")
    }

    /// Lists devices off the main thread (CoreAudio can stall while the HAL settles), then
    /// publishes on main. A newer refresh wins.
    func refresh(then completion: (() -> Void)? = nil) {
        self.refreshGeneration &+= 1
        let generation = self.refreshGeneration
        DispatchQueue.global(qos: .userInitiated).async {
            let devices = AudioDevice.listInputDevicesRefreshingLiveness()
            let clamshellClosed = ClamshellState.isClosed
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.refreshGeneration else { return }
                let rows = Self.rows(from: devices, clamshellClosed: clamshellClosed)
                if let pendingUID = self.pendingUID, rows.contains(where: { $0.id == pendingUID }) == false {
                    DebugLogger.shared.info(
                        "MIC_PICK vanished uid=\(pendingUID) before capture confirmed it",
                        source: "MicrophonePicker"
                    )
                    self.pendingUID = nil
                }
                if rows != self.rows { self.rows = rows }
                completion?()
            }
        }
    }

    private func addDeviceListListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let listener: AudioObjectPropertyListenerBlock = { _, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { MicrophonePickerModel.shared.refresh() }
            }
        }
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, listener
        )
        if status == noErr { self.deviceListListener = listener }
    }

    private func removeDeviceListListener() {
        guard let listener = self.deviceListListener else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, listener
        )
        self.deviceListListener = nil
    }
}

// MARK: - Card

/// The microphone card: the overlay's mic label opens it (DESIGN.md §4's card language, like the
/// history card). Every input device, one 36 pt row each; the one capture is on carries the
/// orange square, a pick still switching the outlined one. A click picks for MouthKeys only; the
/// macOS default input is never touched.
struct SignalMicrophoneCard: View {
    let rows: [MicrophonePickerModel.Row]
    let activeUID: String?
    let pendingUID: String?
    /// Holds a row inverted for renders and inspection, 1-based.
    var inspectionHoverRow: Int?
    let onPick: (MicrophonePickerModel.Row) -> Void
    var onHoverChanged: (Bool) -> Void = { _ in }

    @Environment(\.signalPalette) private var palette
    @State private var hoveredUID: String?

    static let width: CGFloat = 340
    static let rowHeight: CGFloat = 36
    static let markColumn: CGFloat = 30
    static let maxRowsVisible = 10

    private var metrics: SignalTheme.Metrics.Type {
        SignalTheme.Metrics.self
    }

    var body: some View {
        VStack(spacing: 0) {
            self.header
            self.list
            self.footer
        }
        .frame(width: Self.width - 2)
        .padding(1)
        .signalSurface()
        .onHover { hovering in self.onHoverChanged(hovering) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Microphone")
    }

    private var header: some View {
        HStack {
            self.label("Microphone", color: self.palette.text, weight: .semibold)
            Spacer(minLength: 8)
            self.label("Click to use", color: self.palette.text2)
        }
        .padding(.horizontal, self.metrics.historyPaddingHorizontal)
        .frame(height: self.metrics.historyHeader)
        .overlay(alignment: .bottom) { self.rule }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            self.label("MouthKeys only · macOS input unchanged", color: self.palette.text2)
                .padding(.horizontal, self.metrics.historyPaddingHorizontal)
            Spacer(minLength: 0)
        }
        .frame(height: self.metrics.historyFooter)
        .overlay(alignment: .top) { self.rule }
    }

    @ViewBuilder
    private var list: some View {
        let content = VStack(spacing: 0) {
            if self.rows.isEmpty {
                Text("No microphones connected")
                    .font(SignalTheme.Typography.historyTranscript.font)
                    .foregroundStyle(self.palette.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, self.metrics.historyPaddingHorizontal)
                    .frame(height: Self.rowHeight)
            }
            ForEach(Array(self.rows.enumerated()), id: \.element.id) { index, row in
                self.row(row, index: index + 1)
            }
        }
        if self.rows.count > Self.maxRowsVisible {
            ScrollView(.vertical, showsIndicators: false) { content }
                .frame(height: Self.rowHeight * CGFloat(Self.maxRowsVisible))
        } else {
            content
        }
    }

    private func row(_ row: MicrophonePickerModel.Row, index: Int) -> some View {
        let isHovered = row.isUsable && (self.hoveredUID == row.id || self.inspectionHoverRow == index)
        let primary = isHovered ? self.palette.invForeground : (row.isUsable ? self.palette.text : self.palette.textDim)
        let secondary = isHovered ? self.palette.invForeground2 : (row.isUsable ? self.palette.text2 : self.palette.textDim)
        let mark = MicrophonePickerModel.mark(for: row.id, activeUID: self.activeUID, pendingUID: self.pendingUID)
        return Button {
            self.onPick(row)
        } label: {
            HStack(spacing: 0) {
                self.markView(mark, inverted: isHovered)
                    .frame(width: Self.markColumn, alignment: .leading)
                Text(row.device.name)
                    .font(SignalTheme.Typography.historyTranscript.font)
                    .foregroundStyle(primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Fixed width, so a row reading UNAVAILABLE never shifts its name.
                SignalMonoLabel(text: row.isUsable ? row.kind : "Unavailable", color: secondary)
                    .frame(width: 92, alignment: .trailing)
            }
            .padding(.horizontal, self.metrics.historyPaddingHorizontal)
            .frame(height: Self.rowHeight)
            .background(isHovered ? self.palette.invBackground : Color.clear)
            .overlay(alignment: .top) {
                if index > 1 { self.rule }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!row.isUsable)
        .onHover { hovering in
            if hovering {
                self.hoveredUID = row.id
            } else if self.hoveredUID == row.id {
                self.hoveredUID = nil
            }
        }
        .help(row.isUsable ? "Use \(row.device.name) for dictation" : "\(row.device.name) is unavailable")
        .accessibilityLabel(Self.accessibilityLabel(row, mark: mark))
    }

    @ViewBuilder
    private func markView(_ mark: SignalRecordMark, inverted: Bool) -> some View {
        let size = SignalTheme.Metrics.recordSquare
        let color = inverted ? self.palette.invForeground : self.palette.accent
        switch mark {
        case .recording:
            Rectangle().fill(color).frame(width: size, height: size)
        case .closed:
            Rectangle()
                .strokeBorder(color, lineWidth: SignalTheme.Metrics.recordSquareOutline)
                .frame(width: size, height: size)
        case .none:
            Color.clear.frame(width: size, height: size)
        }
    }

    static func accessibilityLabel(_ row: MicrophonePickerModel.Row, mark: SignalRecordMark) -> String {
        var parts = [row.device.name]
        switch mark {
        case .recording: parts.append("in use")
        case .closed: parts.append("switching")
        case .none: break
        }
        if !row.isUsable { parts.append("unavailable") }
        return parts.joined(separator: ", ")
    }

    private func label(_ text: String, color: Color, weight: Font.Weight = .medium) -> some View {
        let role = SignalTheme.Typography.tableLabel
        return Text(text)
            .font(.system(size: role.size, weight: weight, design: .monospaced))
            .tracking(role.tracking)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .lineLimit(1)
    }

    private var rule: some View {
        Rectangle().fill(self.palette.rule).frame(height: 1)
    }
}

// MARK: - Panel

/// The microphone card's panel: a borderless, non-activating panel above the overlay (the
/// History card's placement), so opening it never takes focus from the dictation target.
@MainActor
final class BottomOverlayMicrophonePickerController: ObservableObject {
    static let shared = BottomOverlayMicrophonePickerController()

    /// Open: the overlay's mic label stays inverted (latched).
    @Published private(set) var isOpen = false

    private var panel: NSPanel?
    let floatShadow = SignalFloatShadow { state in SignalFloatShadowView(state: state).signalPalette() }
    private var hostingView: NSHostingView<BottomOverlayMicrophonePickerView>?
    private var labelFrameInScreen: CGRect = .zero
    private var overlayFrameInScreen: CGRect = .zero
    private weak var parentWindow: NSWindow?
    private var sizeObserver: AnyCancellable?
    private var openGeneration = 0
    /// The overlay's mic label on screen, kept current by the label itself.
    let labelAnchor = SignalChipAnchor()

    private init() {}

    /// The mic label's action: opens the card, or closes it when it is open.
    func toggle(labelFrameInScreen: CGRect, overlayFrameInScreen: CGRect, parentWindow: NSWindow?) {
        if self.isOpen {
            self.hide(reason: "label_toggle")
            return
        }
        guard labelFrameInScreen.width > 0, labelFrameInScreen.height > 0 else { return }
        self.labelFrameInScreen = labelFrameInScreen
        self.overlayFrameInScreen = overlayFrameInScreen.width > 0 ? overlayFrameInScreen : labelFrameInScreen
        self.parentWindow = parentWindow

        BottomOverlayHistoryMenuController.shared.hide()
        // Latched at once (the label inverts on the click); the panel follows within one device
        // listing (a few ms), so the card never shows an empty or stale list.
        self.isOpen = true
        self.openGeneration &+= 1
        let generation = self.openGeneration
        MicrophonePickerModel.shared.startWatching { [weak self] in
            guard let self, self.isOpen, generation == self.openGeneration else { return }
            self.createPanelIfNeeded()
            self.attachToParentWindow()
            self.updateFrame()
            self.panel?.orderFrontRegardless()
            DebugLogger.shared.info(
                "MIC_PICKER open devices=\(MicrophonePickerModel.shared.rows.count) " +
                    "active=\(MicrophonePickerModel.shared.activeUID ?? "none")",
                source: "MicrophonePicker"
            )
        }
    }

    func hide(reason: String = "closed") {
        guard self.isOpen || self.panel?.isVisible == true else { return }
        if let panel = self.panel, let parent = panel.parent {
            parent.removeChildWindow(panel)
        }
        self.panel?.orderOut(nil)
        MicrophonePickerModel.shared.stopWatching()
        if self.isOpen { self.isOpen = false }
        DebugLogger.shared.info("MIC_PICKER close reason=\(reason)", source: "MicrophonePicker")
    }

    /// A click outside the card and its label closes it.
    func dismissIfNeeded(for screenPoint: NSPoint) {
        guard self.panel?.isVisible == true else { return }
        let insidePanel = self.panel?.frame.contains(screenPoint) ?? false
        if !insidePanel, !self.labelFrameInScreen.contains(screenPoint) {
            self.hide(reason: "outside_click")
        }
    }

    /// The card's panel and the mic label, in AppKit screen coordinates, for scripted checks.
    var debugFrames: (label: CGRect, card: CGRect?) {
        (self.labelAnchor.frameInScreen, self.panel?.isVisible == true ? self.panel?.frame : nil)
    }

    private func createPanelIfNeeded() {
        guard self.panel == nil else { return }
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none

        let hostingView = NSHostingView(rootView: BottomOverlayMicrophonePickerView(
            floatShadow: self.floatShadow.state,
            onPicked: { [weak self] in self?.hide(reason: "picked") }
        ))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        panel.contentView = hostingView
        self.hostingView = hostingView
        self.panel = panel
        self.floatShadow.attach(to: panel)
        // A device that connects or vanishes changes the card's height: it grows upward from its
        // fixed bottom edge, so the overlay below never moves.
        self.sizeObserver = MicrophonePickerModel.shared.$rows
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateFrame() }
            }
    }

    private func attachToParentWindow() {
        guard let panel = self.panel else { return }
        if let current = panel.parent, current !== self.parentWindow {
            current.removeChildWindow(panel)
        }
        if let parent = self.parentWindow, panel.parent !== parent {
            parent.addChildWindow(panel, ordered: .above)
        }
    }

    private func updateFrame() {
        guard let panel = self.panel, let hostingView = self.hostingView else { return }
        let size = hostingView.fittingSize
        guard size.width > 0, size.height > 0 else { return }
        let screen = self.parentWindow?.screen ?? NSScreen.main
        let frame = BottomOverlayHistoryMenuController.cardFrame(
            panelSize: size,
            overlayFrame: self.overlayFrameInScreen,
            gap: SignalTheme.Metrics.historyGapAboveOverlay,
            insets: SignalTheme.Metrics.windowInsets,
            visibleFrame: screen?.visibleFrame
        )
        if panel.frame != frame { panel.setFrame(frame, display: true) }
    }
}

private struct BottomOverlayMicrophonePickerView: View {
    @ObservedObject private var model = MicrophonePickerModel.shared
    let floatShadow: SignalFloatShadow.State
    let onPicked: () -> Void

    var body: some View {
        SignalMicrophoneCard(
            rows: self.model.rows,
            activeUID: self.model.activeUID,
            pendingUID: self.model.pendingUID,
            onPick: { row in
                self.model.pick(row)
                self.onPicked()
            }
        )
        .signalFloatShadowSource(self.floatShadow)
        .padding(SignalTheme.Metrics.windowInsets)
        .signalPalette()
    }
}
