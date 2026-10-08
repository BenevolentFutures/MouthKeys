//
//  SetupComponents.swift
//  fluid
//
//  Helper components for setup and onboarding UI
//

import AppKit
import SwiftUI

// MARK: - Setup Step View

struct SetupStepView: View {
    @Environment(\.theme) private var theme
    let step: Int
    let title: String
    let description: String
    let status: SetupStatus
    let action: () -> Void
    var actionButtonTitle: String = "Configure"
    var showActionButton: Bool = true

    enum SetupStatus {
        case pending, completed, inProgress
    }

    var body: some View {
        Button(action: {
            if self.status != .completed, self.showActionButton {
                self.action()
            }
        }) {
            HStack(alignment: .center, spacing: 10) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(self.statusColor.opacity(0.12))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(self.statusColor.opacity(0.25), lineWidth: 1)
                        )

                    if self.status == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(self.statusColor)
                            .font(.body.weight(.semibold))
                    } else if self.status == .inProgress {
                        ProgressView()
                            .controlSize(.small)
                            .fixedSize()
                            .tint(self.statusColor)
                    } else {
                        Text("\(self.step)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(self.statusColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(self.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(self.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Action button or status badge
                if self.status == .completed {
                    Label("Done", systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.fluidGreen, in: Capsule())
                } else if self.showActionButton {
                    HStack(spacing: 3) {
                        Text(self.actionButtonTitle)
                            .font(.caption.weight(.medium))
                        Image(systemName: "arrow.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(self.theme.palette.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(self.theme.palette.accent.opacity(0.12), in: Capsule())
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(self.status == .completed
                        ? Color.fluidGreen.opacity(0.06)
                        : self.theme.palette.cardBackground.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                self.status == .completed
                                    ? Color.fluidGreen.opacity(0.25)
                                    : self.theme.palette.cardBorder.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(self.status == .completed || !self.showActionButton)
        .opacity(self.status == .completed ? 0.9 : 1.0)
    }

    private var statusColor: Color {
        switch self.status {
        case .completed: return Color.fluidGreen
        case .inProgress: return .blue
        case .pending: return .secondary
        }
    }
}

// MARK: - Instruction Step

struct InstructionStep: View {
    @Environment(\.theme) private var theme
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill(self.theme.palette.accent.opacity(0.15))
                    .frame(width: 22, height: 22)

                Text("\(self.number)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(self.theme.palette.accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(self.title)
                    .font(.subheadline.weight(.medium))

                Text(self.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Datasheet Getting Started

enum DatasheetSetupStepStatus: Equatable {
    case complete
    case current
    case later
}

enum DatasheetQuickSetupFourthStep: Equatable {
    case pending
    case shortcutPracticed
    case voiceValidated
}

struct DatasheetQuickSetupProgress: Equatable {
    let modelReady: Bool
    let microphoneAuthorized: Bool
    let accessibilityEnabled: Bool
    let hotkeyPracticeCount: Int
    let hotkeyPracticeIsDown: Bool
    let fourthStep: DatasheetQuickSetupFourthStep

    init(
        modelReady: Bool,
        microphoneAuthorized: Bool,
        accessibilityEnabled: Bool,
        hotkeyPracticeCount: Int,
        hotkeyPracticeIsDown: Bool = false,
        playgroundValidated: Bool
    ) {
        self.modelReady = modelReady
        self.microphoneAuthorized = microphoneAuthorized
        self.accessibilityEnabled = accessibilityEnabled
        self.hotkeyPracticeCount = hotkeyPracticeCount
        self.hotkeyPracticeIsDown = hotkeyPracticeIsDown

        if playgroundValidated {
            self.fourthStep = .voiceValidated
        } else if modelReady, microphoneAuthorized, accessibilityEnabled, hotkeyPracticeCount >= 3, !hotkeyPracticeIsDown {
            self.fourthStep = .shortcutPracticed
        } else {
            self.fourthStep = .pending
        }
    }

    var completedSteps: [Bool] {
        [
            self.modelReady,
            self.microphoneAuthorized,
            self.accessibilityEnabled,
            self.fourthStep != .pending,
        ]
    }

    var completedCount: Int {
        self.completedSteps.filter { $0 }.count
    }

    var voiceValidated: Bool {
        self.fourthStep == .voiceValidated
    }

    var currentIndex: Int? {
        self.completedSteps.firstIndex(of: false)
    }
}

@MainActor
enum DatasheetQuickSetupPracticeGate {
    private static var activeTokens = Set<UUID>()

    static func isActive(applicationIsActive: Bool) -> Bool {
        applicationIsActive && !self.activeTokens.isEmpty
    }

    static func activate(token: UUID) {
        self.activeTokens.insert(token)
    }

    static func deactivate(token: UUID) {
        self.activeTokens.remove(token)
    }
}

@MainActor
struct DatasheetQuickSetupPracticeGateLease {
    private let token = UUID()
    private(set) var isArmed = false

    mutating func update(monitorIsArmed: Bool, applicationIsActive: Bool) {
        guard monitorIsArmed, applicationIsActive else {
            self.release()
            return
        }
        guard !self.isArmed else { return }
        DatasheetQuickSetupPracticeGate.activate(token: self.token)
        self.isArmed = true
    }

    mutating func release() {
        guard self.isArmed else { return }
        DatasheetQuickSetupPracticeGate.deactivate(token: self.token)
        self.isArmed = false
    }
}

/// Welcome's modifier drill owns the physical chord until its first configured key release.
/// The shared decision remains pure; no global hotkey or recorder state is changed here.
struct DatasheetPracticeModifierPress {
    private var activeShortcut: HotkeyShortcut?
    private var interrupted = false

    mutating func interrupt() {
        if self.activeShortcut != nil { self.interrupted = true }
    }

    mutating func update(
        shortcut: HotkeyShortcut,
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        pressedKeys: Set<UInt16>
    ) -> ModifierOnlyShortcutFlagsDecision.Outcome {
        let relevantFlags = modifiers.intersection(HotkeyShortcut.relevantModifierMask)
        let physicalFlags = pressedKeys.reduce(into: NSEvent.ModifierFlags()) { flags, code in
            if let flag = HotkeyShortcut.modifierFlag(forKeyCode: code) { flags.insert(flag) }
        }
        var ownedShortcut = self.activeShortcut ?? shortcut
        // A flag-only chord accepts either side. Once armed, retain the actual physical owners
        // so a sibling holding the same aggregate flag cannot hide the owning key's release.
        if self.activeShortcut == nil, shortcut.normalizedModifierKeyCodes.isEmpty,
           relevantFlags == shortcut.expectedModifierFlags, physicalFlags == relevantFlags {
            ownedShortcut = HotkeyShortcut(
                keyCode: shortcut.keyCode,
                modifierFlags: shortcut.modifierFlags,
                modifierKeyCodes: Array(pressedKeys)
            )
        }
        let decision = ModifierOnlyShortcutFlagsDecision.evaluate(
            shortcut: ownedShortcut,
            holdModeType: .transcription,
            isEnabled: self.activeShortcut != nil
                || (relevantFlags == ownedShortcut.expectedModifierFlags && physicalFlags == relevantFlags),
            keyCode: keyCode,
            modifiers: modifiers,
            state: ModifierOnlyShortcutTrackingState(
                pressedModifierKeyCodes: pressedKeys,
                activeModifierOnlyType: self.activeShortcut == nil ? nil : .transcription,
                activeModifierOnlyShortcut: self.activeShortcut,
                otherKeyPressedDuringModifier: self.interrupted,
                isModeKeyPressed: self.activeShortcut != nil
            )
        )
        self.activeShortcut = decision.activeModifierOnlyShortcut
        self.interrupted = decision.otherKeyPressedDuringModifier
        return decision.outcome
    }
}

struct DatasheetSetupStep: Identifiable {
    let number: Int
    let title: String
    let detail: String
    let completedTitle: String
    let completedDetail: String
    let actionTitle: String
    let actionSymbol: String
    let status: DatasheetSetupStepStatus
    let action: () -> Void

    var id: Int { self.number }
}

struct DatasheetQuickSetupReadout: View {
    let steps: [DatasheetSetupStep]
    let completedCount: Int
    let readyShortcut: String
    var voiceValidated = true
    var recoveryHint: AccessibilityHint = .none
    var conflictingCopies: [URL] = []
    var openAccessibilitySettings: () -> Void = {}
    var relaunch: () -> Void = {}

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("QUICK SETUP")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(self.palette.text)
                Spacer(minLength: 12)
                HStack(spacing: 3) {
                    ForEach(self.steps) { step in
                        Rectangle()
                            .fill(step.status == .complete ? self.palette.ink : .clear)
                            .overlay(Rectangle().stroke(self.palette.edge, lineWidth: 1))
                            .frame(width: 22, height: 10)
                    }
                }
                Text("\(self.completedCount)/4")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(self.palette.text)
                    .monospacedDigit()
                    .frame(width: 26, alignment: .trailing)
                DatasheetMonoLabel(text: self.progressTitle, color: self.palette.text2)
                    .frame(width: 94, alignment: .trailing)
            }
            .padding(.horizontal, 18)
            .frame(height: 44)
            .overlay(alignment: .bottom) { Rectangle().fill(self.palette.rule).frame(height: 1) }

            ForEach(self.steps) { step in
                DatasheetQuickSetupStepRow(step: step)
                if step.number == 3, self.recoveryHint != .none {
                    DatasheetAccessibilityRecoveryRow(
                        hint: self.recoveryHint,
                        conflictingCopies: self.conflictingCopies,
                        openAccessibilitySettings: self.openAccessibilitySettings,
                        relaunch: self.relaunch
                    )
                    .padding(.leading, 56)
                    .padding(.trailing, 18)
                    .padding(.vertical, 10)
                }
                if step.number < self.steps.count {
                    Rectangle()
                        .fill(self.palette.ruleSoft)
                        .frame(height: 1)
                }
            }

            if self.completedCount == self.steps.count {
                self.completionFooter
                .padding(.trailing, 18)
                .frame(height: 64)
                .overlay(alignment: .top) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
            }
        }
        .overlay(Rectangle().stroke(self.palette.rule, lineWidth: 1))
    }

    @ViewBuilder
    private var completionFooter: some View {
        if self.voiceValidated {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(self.palette.text)
                    .frame(width: 56)
                Text("You’re set. Press")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(self.palette.text)
                Text(self.readyShortcut)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(self.palette.text)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(self.palette.field)
                    .overlay(Rectangle().stroke(self.palette.edge, lineWidth: 1))
                Text("anywhere and start talking.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(self.palette.text)
                Spacer(minLength: 0)
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(self.palette.text)
                    .frame(width: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Shortcut practiced.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(self.palette.text)
                    Text("Test voice transcription in the Playground.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(self.palette.text2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var progressTitle: String {
        if self.completedCount >= self.steps.count { return "READY" }
        return self.completedCount == 0 ? "NOT STARTED" : "IN PROGRESS"
    }
}

private struct DatasheetQuickSetupStepRow: View {
    let step: DatasheetSetupStep

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        switch self.step.status {
        case .complete:
            Button(action: self.step.action) {
                HStack(spacing: 0) {
                    self.numberLabel(color: self.palette.text2)
                    DatasheetStatusSquare(kind: .ink)
                        .frame(width: 18)
                    Text(self.step.completedTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(self.palette.text2)
                        .lineLimit(1)
                    Spacer(minLength: 12)
                    DatasheetMonoLabel(text: self.step.completedDetail, color: self.palette.textDim)
                        .padding(.trailing, 16)
                    DatasheetMonoLabel(text: "DONE", color: self.palette.text2)
                        .frame(width: 72, alignment: .trailing)
                }
                .frame(height: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(true)

        case .current:
            self.incompleteRow(isCurrent: true)

        case .later:
            self.incompleteRow(isCurrent: false)
        }
    }

    private func incompleteRow(isCurrent: Bool) -> some View {
        Button(action: self.step.action) {
            ViewThatFits(in: .horizontal) {
                self.wideIncompleteRow(isCurrent: isCurrent)
                self.compactIncompleteRow(isCurrent: isCurrent)
            }
            .background(self.palette.surface)
            .overlay(Rectangle().stroke(isCurrent ? self.palette.ink : .clear, lineWidth: isCurrent ? 1.5 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Step \(self.step.number), \(self.step.title). \(self.step.detail). \(self.step.actionTitle).")
    }

    private func wideIncompleteRow(isCurrent: Bool) -> some View {
        HStack(spacing: 0) {
            self.numberLabel(color: isCurrent ? self.palette.invForeground : self.palette.textDim)
                .font(.system(size: isCurrent ? 16 : 12, weight: .semibold, design: .monospaced))
                .frame(maxHeight: .infinity)
                .background(isCurrent ? self.palette.invBackground : .clear)
                .foregroundStyle(isCurrent ? self.palette.invForeground : self.palette.textDim)
            self.titleAndDetail(isCurrent: isCurrent)
                .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
            self.statusLabel(isCurrent: isCurrent)
            self.actionLabel(isCurrent: isCurrent)
                .frame(width: 218)
                .padding(.trailing, 22)
        }
        .frame(minHeight: isCurrent ? 104 : 84)
    }

    private func compactIncompleteRow(isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                self.numberLabel(color: isCurrent ? self.palette.invForeground : self.palette.textDim)
                    .font(.system(size: isCurrent ? 16 : 12, weight: .semibold, design: .monospaced))
                    .frame(maxHeight: .infinity)
                    .background(isCurrent ? self.palette.invBackground : .clear)
                    .foregroundStyle(isCurrent ? self.palette.invForeground : self.palette.textDim)
                self.titleAndDetail(isCurrent: isCurrent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 0) {
                Color.clear.frame(width: 56)
                self.statusLabel(isCurrent: isCurrent)
                Spacer(minLength: 8)
                self.actionLabel(isCurrent: isCurrent)
                    .frame(width: 218)
                    .padding(.trailing, 22)
            }
        }
        .padding(.vertical, 12)
    }

    private func titleAndDetail(isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(self.step.title)
                .font(.system(size: isCurrent ? 18 : 16, weight: .semibold))
                .padding(.horizontal, isCurrent ? 4 : 0)
                .background(isCurrent ? self.palette.invBackground : .clear)
                .foregroundStyle(isCurrent ? self.palette.invForeground : self.palette.text2)
            Text(self.step.detail)
                .font(.system(size: 13, weight: .regular))
                .lineSpacing(2)
                .foregroundStyle(self.palette.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 20)
        .padding(.vertical, 14)
    }

    private func statusLabel(isCurrent: Bool) -> some View {
        HStack(spacing: 8) {
            if isCurrent { DatasheetStatusSquare(kind: .orange, size: 6) }
            DatasheetMonoLabel(
                text: isCurrent ? "DO THIS NOW" : "NEXT",
                color: isCurrent ? self.palette.text : self.palette.text2
            )
        }
        .frame(width: 128, alignment: .leading)
    }

    @ViewBuilder
    private func actionLabel(isCurrent: Bool) -> some View {
        let label = HStack(spacing: 8) {
            Image(systemName: self.step.actionSymbol)
                .font(.system(size: 13, weight: .medium))
            Text(self.step.actionTitle)
                .font(.system(size: 13, weight: isCurrent ? .semibold : .medium))
                .lineLimit(1)
        }
        .frame(minWidth: 194, minHeight: 36)
        .padding(.horizontal, 12)

        if isCurrent {
            DatasheetBracketed(rest: true) {
                label
                    .foregroundStyle(self.palette.invForeground)
                    .background(self.palette.invBackground)
            }
        } else {
            label
                .foregroundStyle(self.palette.text)
                .overlay(Rectangle().stroke(self.palette.edge, lineWidth: 1))
        }
    }

    private func numberLabel(color: Color) -> some View {
        Text(String(format: "%02d", self.step.number))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(color)
            .frame(width: 56, alignment: .center)
    }
}

struct DatasheetWelcomeSectionHeader: View {
    let title: String
    var trailing: String? = nil

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Text(self.title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(self.palette.text)
            Rectangle()
                .fill(self.palette.rule)
                .frame(height: 1)
            if let trailing {
                DatasheetMonoLabel(text: trailing, color: self.palette.text2)
                    .fixedSize()
            }
        }
        .frame(height: 20)
        .accessibilityElement(children: .combine)
    }
}

struct DatasheetAccessibilityRecoveryRow: View {
    let hint: AccessibilityHint
    var conflictingCopies: [URL] = []
    let openAccessibilitySettings: () -> Void
    let relaunch: () -> Void

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        switch self.hint {
        case .none:
            EmptyView()
        case .staleGrant:
            self.content(
                headline: AccessibilityHintPolicy.staleGrantHeadline,
                message: AccessibilityHintPolicy.staleGrantBody,
                primaryTitle: "Open Accessibility Settings",
                primaryAction: self.openAccessibilitySettings
            )
        case .conflictingCopies:
            self.content(
                headline: AccessibilityHintPolicy.conflictingCopiesHeadline,
                message: AccessibilityHintPolicy.conflictingCopiesBody,
                paths: self.conflictingCopies.prefix(3).map { ConflictingAppCopyDetector.displayPath($0) },
                primaryTitle: "Show in Finder",
                primaryAction: {
                    NSWorkspace.shared.activateFileViewerSelecting(Array(self.conflictingCopies.prefix(3)))
                },
                secondaryTitle: "Open Accessibility Settings",
                secondaryAction: self.openAccessibilitySettings
            )
        case .relaunch:
            self.content(
                headline: AccessibilityHintPolicy.relaunchHeadline,
                message: AccessibilityHintPolicy.relaunchBody,
                primaryTitle: "Relaunch MouthKeys",
                primaryAction: self.relaunch
            )
        }
    }

    private func content(
        headline: String,
        message: String,
        paths: [String] = [],
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            DatasheetStatusSquare(kind: .orange, size: 8)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 5) {
                Text(headline)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(0.3)
                    .foregroundStyle(self.palette.text)
                ForEach(paths, id: \.self) { path in
                    Text(path)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(self.palette.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Text(message)
                    .font(.system(size: 12, weight: .regular))
                    .lineSpacing(2)
                    .foregroundStyle(self.palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    self.actionButton(primaryTitle, action: primaryAction, isPrimary: true)
                    if let secondaryTitle, let secondaryAction {
                        self.actionButton(secondaryTitle, action: secondaryAction, isPrimary: false)
                    }
                }
                .padding(.top, 3)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(self.palette.field)
        .overlay(Rectangle().stroke(self.palette.edge, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(headline) \(message)")
    }

    private func actionButton(_ title: String, action: @escaping () -> Void, isPrimary: Bool) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.2)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(isPrimary ? self.palette.accent : self.palette.text2)
            .contentShape(Rectangle())
        }
        .buttonStyle(DatasheetTextButtonStyle())
    }
}

struct DatasheetKeyPracticeReadout: View {
    let shortcut: String
    let mode: HotkeyActivationMode
    let pressCount: Int
    let isPracticing: Bool
    let isDown: Bool
    let practicePress: () -> Void
    let reset: () -> Void
    let changeShortcut: () -> Void

    @Environment(\.datasheetPalette) private var palette

    private var practiceHeadline: String {
        self.pressCount >= 3 ? "That’s your key." : "Press \(self.shortcut) now"
    }

    private var practiceDetail: String {
        if self.pressCount >= 3 { return "You can change this in Settings at any time." }
        if !self.isPracticing { return "Press Reset to practice your shortcut." }
        return self.shortcut == "Right ⌥"
            ? "The Option key right of the space bar. Press and let go, three times."
            : "Press and let go, three times. Use the keycap if needed."
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 12) {
                DatasheetBracketed(rest: true) {
                    Button(action: self.practicePress) {
                        Text(self.shortcut.uppercased())
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(self.isDown ? self.palette.invForeground : self.palette.text)
                            .frame(width: 188, height: 88)
                            .background(self.isDown ? self.palette.invBackground : self.palette.field)
                            .overlay(Rectangle().stroke(self.palette.edge, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Click to practice \(self.shortcut)")
                }

                HStack(spacing: 8) {
                    Text(self.mode.displayName.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(self.palette.text)
                    Rectangle().fill(self.palette.rule).frame(width: 1, height: 12)
                    Text(self.mode.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(self.palette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: self.changeShortcut) {
                    HStack(spacing: 6) {
                        Text("CHANGE KEY OR MODE")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.3)
                    .foregroundStyle(self.palette.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(DatasheetTextButtonStyle())
            }
            .frame(width: 252, alignment: .leading)
            .padding(.trailing, 24)

            Rectangle()
                .fill(self.palette.rule)
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 9) {
                DatasheetMonoLabel(text: "Practice", color: self.palette.text2)
                Text(self.practiceHeadline)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(self.palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(self.practiceDetail)
                    .font(.system(size: 12, weight: .regular))
                    .lineSpacing(2)
                    .foregroundStyle(self.palette.text2)
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 22) {
                        self.practiceKeyStatus
                        self.practicePressCount
                        self.practiceMeter
                    }
                    // Keep the same layout choice for KEY UP and KEY DOWN.
                    .frame(minWidth: 240, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 22) {
                            self.practiceKeyStatus
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(width: 48, alignment: .leading)
                            self.practicePressCount
                        }
                        self.practiceMeter
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) {
                        self.practiceReset
                        self.practiceFallbackHint
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    VStack(alignment: .leading, spacing: 8) {
                        self.practiceReset
                        self.practiceFallbackHint
                    }
                }
            }
            .padding(.leading, 26)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 18)
    }

    private var practiceKeyStatus: some View {
        VStack(alignment: .leading, spacing: 5) {
            DatasheetMonoLabel(text: "Key", color: self.palette.text2)
            HStack(spacing: 7) {
                DatasheetStatusSquare(kind: self.isDown ? .orange : .outline)
                Text(self.isDown ? "DOWN" : "UP")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(self.palette.text)
            }
        }
    }

    private var practicePressCount: some View {
        VStack(alignment: .leading, spacing: 5) {
            DatasheetMonoLabel(text: "Presses", color: self.palette.text2)
            Text("\(self.pressCount)/3")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(self.palette.text)
                .monospacedDigit()
        }
    }

    private var practiceMeter: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .fill(index < self.pressCount ? (self.pressCount >= 3 && !self.isDown ? self.palette.accent : self.palette.ink) : .clear)
                    .overlay(Rectangle().stroke(self.palette.edge, lineWidth: 1))
                    .frame(width: 22, height: 10)
            }
        }
        .accessibilityLabel("\(self.pressCount) of 3 presses")
    }

    private var practiceReset: some View {
        Button(action: self.reset) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                Text("RESET")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(0.3)
            .foregroundStyle(self.palette.text2)
        }
        .buttonStyle(DatasheetTextButtonStyle())
    }

    private var practiceFallbackHint: some View {
        Text("No key? Click the keycap.")
            .font(DatasheetTheme.Typography.meta.font)
            .tracking(DatasheetTheme.Typography.meta.tracking)
            .textCase(.uppercase)
            .foregroundStyle(self.palette.text2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct DatasheetCalloutCopy: Identifiable {
    let id: String
    let title: String
    let description: String

    static let all: [DatasheetCalloutCopy] = [
        .init(id: "history", title: "Recent Dictations", description: "Recent dictations · click one to insert"),
        .init(id: "copy", title: "Copy", description: "Copy the last transcription"),
        .init(id: "cancel", title: "Cancel", description: "Discard this dictation · Esc"),
        .init(id: "reprocess", title: "Reprocess", description: "Transcribe the last audio again"),
        .init(id: "preview", title: "Preview", description: "The words so far, newest at the end"),
        .init(id: "trace", title: "Voice Trace", description: "12 bars a second of voice · orange head is now"),
        .init(id: "record", title: "Recording", description: "Solid: listening · hollow: transcribing"),
        .init(id: "timer", title: "Timer", description: "Length of this dictation"),
        .init(id: "wc", title: "Word Count", description: "Words in this dictation"),
        .init(id: "wpm", title: "Words per Minute", description: "Your pace, this dictation"),
        .init(id: "app", title: "Target App", description: "Where the text will paste"),
        .init(id: "mic", title: "Microphone", description: "The microphone, with the lapel’s battery"),
    ]
}

struct DatasheetCalloutZone: Identifiable {
    let id: String
    let frame: CGRect
}

/// The teaching reference alone fits to its canvas. The pill, rails and all hover regions use
/// this same transform; the live overlay retains its original size and placement.
struct DatasheetInlineOverlayLayout {
    let geometry: DatasheetOverlayGeometry
    let canvasWidth: CGFloat

    var compositionWidth: CGFloat {
        self.geometry.pillWidth + 2 * (DatasheetTheme.Metrics.chip + DatasheetTheme.Metrics.railGap)
    }

    var overlayRowHeight: CGFloat {
        max(self.geometry.railHeight, self.geometry.pillHeight)
    }

    var scale: CGFloat {
        // Keep the chips' outside brackets and zone outlines inside the reference's edge.
        min(1, max(0, self.canvasWidth - 2 * DatasheetTheme.Metrics.windowInsets.leading) / self.compositionWidth)
    }

    var originX: CGFloat {
        (self.canvasWidth - self.compositionWidth * self.scale) / 2
    }

    func fittedFrame(_ rect: CGRect) -> CGRect {
        CGRect(
            x: self.originX + rect.minX * self.scale, y: rect.minY * self.scale,
            width: rect.width * self.scale, height: rect.height * self.scale
        )
    }

    func outlineStyle(for id: String, activeCallout: String?) -> StrokeStyle {
        StrokeStyle(lineWidth: 1, dash: activeCallout == id ? [] : [3, 3])
    }

    private var pillHeight: CGFloat { self.geometry.pillHeight }

    func calloutZones(micText: String, micBattery: DatasheetMicBattery?) -> [DatasheetCalloutZone] {
        let metrics = DatasheetTheme.Metrics.self
        let chip = metrics.chip
        let railGap = metrics.railGap
        let railHeight = self.geometry.railHeight
        let railInset = DatasheetRail<EmptyView, EmptyView, EmptyView>.gap(height: railHeight)
        let compositionX: CGFloat = 0
        let pillX = compositionX + chip + railGap
        let pillY = max(0, self.overlayRowHeight - self.pillHeight)
        let traceY = pillY + metrics.pillPaddingTop + self.geometry.topAreaHeight + metrics.previewGap
        let footY = traceY + metrics.traceRowHeight + metrics.micGap
        let readoutX = pillX + metrics.pillPaddingHorizontal + self.geometry.innerWidth - self.geometry.readoutWidth
        let timerX = readoutX + metrics.recordSquare + metrics.readoutGap
        let traceWidth = max(12, self.geometry.innerWidth - self.geometry.readoutWidth - metrics.traceReadoutGap)
        let micRole = DatasheetTheme.Typography.micLabel
        let micWidth: CGFloat
        if let micBattery {
            micWidth = DatasheetMicLabel.layout(
                prefix: "", battery: micBattery, maxWidth: metrics.micMaxWidth, width: micRole.width(of:)
            ).width
        } else {
            micWidth = min(metrics.micMaxWidth, micRole.width(of: micText.uppercased()) + 1)
        }
        let pairWidth = metrics.targetIcon + metrics.footGap + micWidth
        let pairX = pillX + metrics.pillPaddingHorizontal + (self.geometry.innerWidth - pairWidth) / 2
        let topChipY = railInset + chip / 2
        let bottomChipY = railHeight - railInset - chip / 2
        let traceRect = CGRect(x: pillX + metrics.pillPaddingHorizontal, y: traceY, width: traceWidth, height: metrics.traceRowHeight)
        let timerLineY = traceY + metrics.traceMidline - DatasheetTheme.Typography.timer.lineHeight / 2

        return [
            DatasheetCalloutZone(id: "history", frame: CGRect(x: compositionX, y: topChipY - chip / 2, width: chip, height: chip)),
            DatasheetCalloutZone(id: "copy", frame: CGRect(x: compositionX, y: bottomChipY - chip / 2, width: chip, height: chip)),
            DatasheetCalloutZone(id: "cancel", frame: CGRect(x: pillX + self.geometry.pillWidth + railGap, y: topChipY - chip / 2, width: chip, height: chip)),
            DatasheetCalloutZone(id: "reprocess", frame: CGRect(x: pillX + self.geometry.pillWidth + railGap, y: bottomChipY - chip / 2, width: chip, height: chip)),
            DatasheetCalloutZone(
                id: "preview",
                frame: CGRect(x: pillX + metrics.pillPaddingHorizontal, y: pillY + metrics.pillPaddingTop, width: self.geometry.innerWidth, height: self.geometry.topAreaHeight)
            ),
            DatasheetCalloutZone(id: "trace", frame: traceRect),
            DatasheetCalloutZone(
                id: "record",
                frame: CGRect(x: readoutX, y: timerLineY, width: metrics.recordSquare, height: DatasheetTheme.Typography.timer.lineHeight)
            ),
            DatasheetCalloutZone(
                id: "timer",
                frame: CGRect(x: timerX, y: timerLineY, width: metrics.timerBoxWidth, height: DatasheetTheme.Typography.timer.lineHeight)
            ),
            DatasheetCalloutZone(
                id: "wc",
                frame: CGRect(x: pillX + metrics.pillPaddingHorizontal, y: footY, width: 68, height: metrics.micRowHeight)
            ),
            DatasheetCalloutZone(
                id: "wpm",
                frame: CGRect(x: pillX + metrics.pillPaddingHorizontal + self.geometry.innerWidth - 76, y: footY, width: 76, height: metrics.micRowHeight)
            ),
            DatasheetCalloutZone(
                id: "app",
                frame: CGRect(x: pairX, y: footY + (metrics.micRowHeight - metrics.targetIcon) / 2, width: metrics.targetIcon, height: metrics.targetIcon)
            ),
            DatasheetCalloutZone(
                id: "mic",
                frame: CGRect(x: pairX + metrics.targetIcon + metrics.footGap, y: footY, width: micWidth, height: metrics.micRowHeight)
            ),
        ].map { DatasheetCalloutZone(id: $0.id, frame: self.fittedFrame($0.frame)) }
    }
}

struct DatasheetInlineOverlayPreview: View {
    let fallbackText: String
    var inspectionHover: String?

    @ObservedObject private var model = DatasheetOverlayModel.shared
    @ObservedObject private var contentState = NotchContentState.shared
    @ObservedObject private var settings = SettingsStore.shared
    @Environment(\.datasheetPalette) private var palette
    @State private var activeCallout: String?

    private var geometry: DatasheetOverlayGeometry {
        DatasheetOverlayGeometry.forSize(self.settings.overlaySize)
    }

    private var overlayDisplay: BottomOverlayView.Display {
        BottomOverlayView.display(contentState: self.contentState, model: self.model)
    }

    private var previewText: String {
        let live = self.contentState.cachedPreviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty, !DatasheetOverlayModel.statusWords.contains(live) { return live }
        let final = self.fallbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        return final.isEmpty ? "Press record to watch the pill and playground fill together." : final
    }

    private var micText: String {
        let name = self.model.microphoneName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Microphone" : name
    }

    private var pillHeight: CGFloat {
        DatasheetTheme.Metrics.pillPaddingTop + self.geometry.topAreaHeight + DatasheetTheme.Metrics.previewGap
            + DatasheetTheme.Metrics.traceRowHeight + DatasheetTheme.Metrics.micGap
            + DatasheetTheme.Metrics.micRowHeight + DatasheetTheme.Metrics.pillPaddingBottom
    }

    private var overlayRowHeight: CGFloat {
        max(self.geometry.railHeight, self.pillHeight)
    }

    private var visibleCallout: String? {
        self.inspectionHover ?? self.activeCallout
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = DatasheetInlineOverlayLayout(geometry: self.geometry, canvasWidth: proxy.size.width)
            let zones = layout.calloutZones(micText: self.micText, micBattery: self.model.micBattery)
            ZStack(alignment: .topLeading) {
                self.composition
                    .frame(width: layout.compositionWidth, height: self.overlayRowHeight, alignment: .top)
                    .scaleEffect(layout.scale, anchor: .topLeading)
                    .frame(
                        width: layout.compositionWidth * layout.scale,
                        height: self.overlayRowHeight * layout.scale,
                        alignment: .topLeading
                    )
                    .offset(x: layout.originX)

                ForEach(zones) { zone in
                    Rectangle()
                        .stroke(
                            self.palette.accent,
                            style: layout.outlineStyle(for: zone.id, activeCallout: self.visibleCallout)
                        )
                        .frame(width: zone.frame.width + 6, height: zone.frame.height + 6)
                        .position(x: zone.frame.midX, y: zone.frame.midY)
                        .allowsHitTesting(false)
                }

                if let id = self.visibleCallout,
                   let zone = zones.first(where: { $0.id == id }),
                   let copy = DatasheetCalloutCopy.all.first(where: { $0.id == id }) {
                    let rect = zone.frame
                    self.calloutLeader(from: rect, canvas: proxy.size)
                        .stroke(self.palette.text2, lineWidth: 1)
                        .allowsHitTesting(false)

                    Rectangle()
                        .fill(self.palette.text)
                        .frame(width: 3, height: 3)
                        .position(x: rect.midX, y: rect.maxY)
                        .allowsHitTesting(false)

                    self.calloutCard(copy)
                        .frame(width: min(280, proxy.size.width - 24), alignment: .leading)
                        .position(
                            x: rect.midX < proxy.size.width / 2
                                ? 12 + min(140, proxy.size.width / 2 - 12)
                                : proxy.size.width - 12 - min(140, proxy.size.width / 2 - 12),
                            y: self.overlayRowHeight + 36
                        )
                        .allowsHitTesting(false)
                }

                ForEach(zones) { zone in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(width: zone.frame.width, height: zone.frame.height)
                        .position(x: zone.frame.midX, y: zone.frame.midY)
                        .onHover { self.setHover(zone.id, hovering: $0) }
                        .accessibilityHidden(true)
                }
            }
        }
        // Reserve the same teaching/card band across width and hover changes.
        .frame(height: self.overlayRowHeight + 58)
        .datasheetPalette()
    }

    private var composition: some View {
        HStack(alignment: .bottom, spacing: DatasheetTheme.Metrics.railGap) {
            DatasheetRail(height: self.geometry.railHeight) {
                self.chip("history", icon: "clock.arrow.circlepath", help: "Recent Dictations")
            } middle: {
                Color.clear
            } bottom: {
                self.chip("copy", icon: "doc.on.doc", help: "Copy")
            }

            self.pill

            DatasheetRail(height: self.geometry.railHeight) {
                self.chip("cancel", icon: "xmark", help: "Cancel")
            } middle: {
                Color.clear
            } bottom: {
                self.chip("reprocess", icon: "arrow.clockwise", help: "Reprocess")
            }
        }
    }

    private var pill: some View {
        let trace = self.model.trace
        let mark: DatasheetRecordMark
        switch self.overlayDisplay {
        case .listening: mark = .recording
        case .stopped, .transcribing: mark = .closed
        case .delivered, .notice, .noticeRow, .idle: mark = .none
        }
        let timer: DatasheetTimerReadout
        if self.overlayDisplay == .listening, let start = self.model.recordingStartedAt {
            timer = .running(start)
        } else {
            timer = .frozen(self.model.timerText(at: Date()), dim: false)
        }
        let liveCounters = BottomOverlayView.counterInput(
            display: self.overlayDisplay,
            countsLiveWords: self.model.countsLiveWords,
            recordingStartedAt: self.model.recordingStartedAt,
            frozenDuration: self.model.frozenDuration,
            frozenWords: self.model.frozenWordCount,
            live: self.contentState.liveWordCount,
            hasLiveText: self.settings.enableStreamingPreview && self.settings.selectedSpeechModel.supportsStreaming
        )
        let counters: DatasheetCounterInput?
        if let liveCounters {
            counters = liveCounters
        } else if self.overlayDisplay == .idle {
            counters = DatasheetCounterInput(recording: .distantPast, words: 0, clock: .frozen(0))
        } else {
            counters = nil
        }

        return DatasheetPill(
            geometry: self.geometry,
            topHeight: self.geometry.topAreaHeight,
            traceRow: DatasheetTraceRow(
                geometry: self.geometry,
                trace: trace,
                isLive: self.overlayDisplay == .listening && trace.isLive,
                isSweeping: self.overlayDisplay == .transcribing,
                drain: nil,
                mark: mark,
                timer: timer
            ),
            foot: DatasheetFootRow(
                icon: self.contentState.targetAppIcon,
                micText: self.micText,
                counters: counters,
                counterClock: self.model.counterClock,
                placard: self.model.stopPlacard,
                micBattery: self.model.micBattery
            )
        ) {
            self.topArea
        }
    }

    @ViewBuilder
    private var topArea: some View {
        switch self.overlayDisplay {
        case let .delivered(delivery):
            DatasheetDeliveredStatement(delivery: delivery, isCompact: self.geometry.isCompactTop)
        case .listening, .stopped, .transcribing, .idle:
            DatasheetPreview(
                text: self.previewText,
                lines: self.geometry.previewLines,
                height: self.geometry.topAreaHeight,
                width: self.geometry.innerWidth,
                isDimmed: self.overlayDisplay == .transcribing
            )
        case .notice:
            DatasheetNoticeRow(
                message: self.contentState.aiProcessingFailureMessage,
                canRetry: self.contentState.canRetryAIProcessingFailure,
                isCompact: self.geometry.isCompactTop,
                onRetry: {},
                onDismiss: {}
            )
        case let .noticeRow(notice):
            DatasheetInlineNotice(
                notice: notice,
                isHoverForced: nil,
                onHoverChanged: { _, _ in },
                onReprocess: {},
                onDismiss: {}
            )
        }
    }


    private func chip(_ id: String, icon: String, help: String) -> some View {
        DatasheetChip(
            systemName: icon,
            help: help,
            isHoverForced: self.visibleCallout == id,
            action: {}
        )
        .allowsHitTesting(false)
    }

    private func calloutCard(_ callout: DatasheetCalloutCopy) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(callout.title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(self.palette.text)
            Text(callout.description)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(self.palette.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(self.palette.surface)
        .overlay(Rectangle().stroke(self.palette.edge, lineWidth: 1))
    }

    private func calloutLeader(from rect: CGRect, canvas: CGSize) -> Path {
        var path = Path()
        let origin = CGPoint(x: rect.midX, y: rect.maxY)
        let elbowY = min(canvas.height - 48, self.overlayRowHeight + 8)
        let isLeft = rect.midX < canvas.width / 2
        let endX = isLeft ? 12 : canvas.width - 12
        path.move(to: origin)
        path.addLine(to: CGPoint(x: origin.x, y: elbowY))
        path.addLine(to: CGPoint(x: endX, y: elbowY))
        return path
    }

    private func setHover(_ id: String, hovering: Bool) {
        if hovering {
            self.activeCallout = id
        } else if self.activeCallout == id {
            self.activeCallout = nil
        }
    }
}
