import SwiftUI

struct OnboardingTryoutStepView: View {
    @Binding var finalText: String

    let language: VoiceEngineLanguage
    let shortcutDisplay: String
    let isReady: Bool
    let isRunning: Bool
    let isRecordingShortcut: Bool
    let shortcutRecordingMessage: String?
    let footerHint: String?
    let onToggleShortcut: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.datasheetPalette) private var palette
    @FocusState private var isEditorFocused: Bool
    @State private var isShortcutKeyPressed = false
    @State private var isShortcutGlowActive = false
    @State private var shortcutAnimationRevision = 0
    @State private var regionalOfferAnswered = false

    init(
        finalText: Binding<String>,
        language: VoiceEngineLanguage,
        shortcutDisplay: String,
        isReady: Bool,
        isRunning: Bool,
        isRecordingShortcut: Bool,
        shortcutRecordingMessage: String?,
        footerHint: String? = nil,
        onToggleShortcut: @escaping () -> Void
    ) {
        self._finalText = finalText
        self.language = language
        self.shortcutDisplay = shortcutDisplay
        self.isReady = isReady
        self.isRunning = isRunning
        self.isRecordingShortcut = isRecordingShortcut
        self.shortcutRecordingMessage = shortcutRecordingMessage
        self.footerHint = footerHint
        self.onToggleShortcut = onToggleShortcut
    }

    private static let languageExamples: [String: [String]] = [
        "ar": [
            "ذكرني أن أرسل الملاحظات قبل الخامسة.",
            "اكتب رسالة قصيرة عن اجتماع اليوم.",
        ],
        "de": [
            "Erinnere mich daran, die Notizen vor fünf zu senden.",
            "Schreib eine kurze Nachricht über das heutige Treffen.",
        ],
        "en": [
            "Remind me to send the notes before five.",
            "Write a short update about today's meeting.",
        ],
        "es": [
            "Recuérdame enviar las notas antes de las cinco.",
            "Escribe una breve actualización sobre la reunión de hoy.",
        ],
        "fr": [
            "Rappelle-moi d'envoyer les notes avant cinq heures.",
            "Écris un court message sur la réunion d'aujourd'hui.",
        ],
        "hi": [
            "मुझे पाँच बजे से पहले नोट्स भेजने की याद दिलाना।",
            "आज की मीटिंग के बारे में एक छोटा अपडेट लिखो।",
        ],
        "it": [
            "Ricordami di inviare gli appunti prima delle cinque.",
            "Scrivi un breve aggiornamento sulla riunione di oggi.",
        ],
        "ja": [
            "5時前にメモを送るようにリマインドして。",
            "今日の会議について短い更新を書いて。",
        ],
        "ko": [
            "다섯 시 전에 메모를 보내라고 알려줘.",
            "오늘 회의에 대한 짧은 업데이트를 써줘.",
        ],
        "nl": [
            "Herinner me eraan om de notities voor vijf uur te sturen.",
            "Schrijf een korte update over de vergadering van vandaag.",
        ],
        "pl": [
            "Przypomnij mi, żeby wysłać notatki przed piątą.",
            "Napisz krótką aktualizację o dzisiejszym spotkaniu.",
        ],
        "pt": [
            "Lembre-me de enviar as notas antes das cinco.",
            "Escreva uma breve atualização sobre a reunião de hoje.",
        ],
        "ru": [
            "Напомни мне отправить заметки до пяти.",
            "Напиши короткое обновление о сегодняшней встрече.",
        ],
        "ta": [
            "ஐந்து மணிக்கு முன் குறிப்புகளை அனுப்ப நினைவூட்டு.",
            "இன்றைய கூட்டத்தைப் பற்றி ஒரு குறுகிய புதுப்பிப்பு எழுது.",
        ],
        "uk": [
            "Нагадай мені надіслати нотатки до п'ятої.",
            "Напиши коротке оновлення про сьогоднішню зустріч.",
        ],
        "vi": [
            "Nhắc tôi gửi ghi chú trước năm giờ.",
            "Viết một cập nhật ngắn về cuộc họp hôm nay.",
        ],
        "zh": [
            "提醒我五点前发送笔记。",
            "写一段关于今天会议的简短更新。",
        ],
    ]

    private var exampleTexts: [String] {
        Self.languageExamples[self.language.id] ?? []
    }

    private var promptText: String {
        if self.exampleTexts.isEmpty {
            return "Say anything you'd want to dictate in \(self.language.displayName)."
        }
        return "Try this, or say anything you'd want to dictate."
    }

    private var hasText: Bool {
        !self.finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowPlaceholder: Bool {
        !self.hasText && !self.isEditorFocused
    }

    private var placeholderText: String {
        if self.isReady {
            return "Click here to test MouthKeys"
        }
        return self.isRunning ? "Listening..." : "Your dictation will appear here..."
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                self.datasheetKeyboardCard
                self.datasheetEditorPanel
            }

            ZStack {
                if let offer = self.regionalOffer {
                    self.datasheetRegionalOfferRow(offer)
                } else {
                    Text(self.footerHint ?? "Feels slow or inaccurate? Go back and try another model for \(self.language.displayName).")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(self.palette.text2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(height: 40, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            self.isShortcutGlowActive = self.isRunning
        }
        .onChange(of: self.isRunning) { _, newValue in
            self.animateShortcutKeyToggle(to: newValue)
        }
    }

    /// Shown after the first dictation lands, and read from what was just said, so a dictated
    /// "ope" can turn the Minnesota question into a statement.
    private var regionalOffer: RegionalFillerOffer? {
        guard !self.regionalOfferAnswered, self.hasText, !self.isRunning else { return nil }
        return RegionalFillerOffer.offer(dictation: self.finalText)
    }

    private func answerRegionalOffer(_ offer: RegionalFillerOffer, keep: Bool) {
        offer.answer(keep: keep, surface: "onboarding")
        self.regionalOfferAnswered = true
    }

    private var datasheetKeyboardCard: some View {
        VStack(spacing: 6) {
            Text("YOUR DICTATION KEY")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(self.palette.text2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Text(self.isRecordingShortcut ? "PRESS KEY…" : self.shortcutDisplay)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(self.palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(width: 144, height: 74)
                .background(self.palette.chip)
                .overlay(Rectangle().stroke(self.isShortcutGlowActive ? self.palette.accent : self.palette.rule, lineWidth: 1))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(self.palette.text)
                        .frame(height: 3)
                        .offset(y: self.isShortcutKeyPressed ? 2 : 0)
                }
                .offset(y: self.isShortcutKeyPressed ? 2 : 0)
                .accessibilityLabel("Current shortcut \(self.shortcutDisplay)")

            HStack(spacing: 6) {
                DatasheetStatusSquare(kind: self.isReady ? .ink : (self.isRecordingShortcut ? .orange : .outline), size: 5)
                if let shortcutRecordingMessage = self.shortcutRecordingMessage {
                    Text(shortcutRecordingMessage)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(self.palette.text2)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(self.isReady ? "TEST COMPLETE" : (self.isRecordingShortcut ? "PRESS A KEY" : "READY TO TEST"))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(0.25)
                        .foregroundStyle(self.palette.text2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .leading)

            Spacer(minLength: 0)

            Button {
                self.onToggleShortcut()
            } label: {
                Text(self.isRecordingShortcut ? "Cancel" : "Change")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(self.palette.text)
                    .frame(width: 88, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(self.isRunning)
            .opacity(self.isRunning ? 0.45 : 1)
            .datasheetHoverBracket()
        }
        .padding(12)
        .frame(width: 208, height: 208)
        .background(self.palette.surface)
        .overlay(Rectangle().stroke(self.palette.rule, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dictation shortcut \(self.shortcutDisplay). Press once to start. Press again to stop.")
    }

    private var datasheetEditorPanel: some View {
        let examples = Array(self.exampleTexts.prefix(1))

        return VStack(alignment: .leading, spacing: 0) {
            Text(self.promptText.uppercased())
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(0.35)
                .foregroundStyle(self.palette.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .frame(height: 34, alignment: .leading)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(self.palette.rule).frame(height: 1)
                }

            Text(examples.first.map { "“\($0)”" } ?? "Say anything you'd want to dictate in \(self.language.displayName).")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(self.palette.text)
                .lineSpacing(3)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 62, maxHeight: 62, alignment: .leading)
                .padding(.horizontal, 12)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
                }

            ZStack(alignment: .topLeading) {
                TextEditor(text: self.$finalText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(self.palette.text)
                    .frame(maxWidth: .infinity, minHeight: 98, maxHeight: 98)
                    .padding(8)
                    .background(self.palette.field)
                    .scrollContentBackground(.hidden)
                    .focused(self.$isEditorFocused)
                    .accessibilityLabel("Dictation practice text")

                if self.shouldShowPlaceholder {
                    Text(self.placeholderText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(self.palette.text2.opacity(0.75))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 98, maxHeight: 98)
        }
        .frame(maxWidth: .infinity, minHeight: 208, maxHeight: 208)
        .background(self.palette.surface)
        .overlay(Rectangle().stroke(self.palette.rule, lineWidth: 1))
    }

    private func datasheetRegionalOfferRow(_ offer: RegionalFillerOffer) -> some View {
        HStack(spacing: 8) {
            DatasheetStatusSquare(kind: .orange, size: 5)

            Text(offer.message)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(self.palette.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 4)

            self.datasheetRegionalOfferButton(offer.keepTitle, prominent: true) {
                self.answerRegionalOffer(offer, keep: true)
            }
            self.datasheetRegionalOfferButton("No thanks", prominent: false) {
                self.answerRegionalOffer(offer, keep: false)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .overlay(alignment: .top) {
            Rectangle().fill(self.palette.rule).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.palette.rule).frame(height: 1)
        }
    }

    private func datasheetRegionalOfferButton(_ title: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(prominent ? self.palette.invForeground : self.palette.text)
                .lineLimit(1)
                .frame(width: 82, height: 28)
                .background(prominent ? self.palette.invBackground : self.palette.surface)
                .overlay(Rectangle().stroke(prominent ? self.palette.invBackground : self.palette.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .datasheetHoverBracket()
        .accessibilityLabel(title)
    }

    private func animateShortcutKeyToggle(to isListening: Bool) {
        self.shortcutAnimationRevision += 1
        let revision = self.shortcutAnimationRevision

        if self.reduceMotion {
            self.isShortcutKeyPressed = false
            self.isShortcutGlowActive = isListening
            return
        }

        withAnimation(.easeOut(duration: 0.055)) {
            self.isShortcutKeyPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            guard self.shortcutAnimationRevision == revision else {
                return
            }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.72, blendDuration: 0.02)) {
                self.isShortcutKeyPressed = false
                self.isShortcutGlowActive = isListening
            }
        }
    }
}
