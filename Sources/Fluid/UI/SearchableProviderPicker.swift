//
//  SearchableProviderPicker.swift
//  Fluid
//
//  A searchable picker for selecting AI providers.
//  Uses a popover with search field for better UX when there are many providers.
//

import SwiftUI

enum SearchablePickerAppearance: Equatable {
    case standard
    case datasheet
}

struct SearchablePickerControlAppearance: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.datasheetPalette) private var palette
    let appearance: SearchablePickerAppearance
    let width: CGFloat?
    let height: CGFloat?
    let usesMaterial: Bool
    let showsShadow: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if self.appearance == .standard {
            content.searchablePickerControlChrome(
                width: self.width,
                height: self.height,
                usesMaterial: self.usesMaterial,
                showsShadow: self.showsShadow
            )
        } else {
            let picker = self.theme.metrics.pickerControl
            content
                .frame(width: self.width, alignment: .leading)
                .frame(maxWidth: self.width == nil ? .infinity : nil, alignment: .leading)
                .padding(.horizontal, picker.horizontalPadding)
                .padding(.vertical, picker.verticalPadding)
                .frame(height: self.height)
                .contentShape(Rectangle())
                .background(self.palette.field)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
        }
    }
}

struct SearchablePickerDisclosure: View {
    @Environment(\.theme) private var theme
    @Environment(\.datasheetPalette) private var palette
    let appearance: SearchablePickerAppearance
    let standardBackgroundOpacity: Double

    @ViewBuilder
    var body: some View {
        if self.appearance == .standard {
            FluidPickerDisclosureIcon(backgroundOpacity: self.standardBackgroundOpacity)
        } else {
            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundStyle(self.palette.text2)
                .frame(
                    width: self.theme.metrics.pickerControl.disclosureSize,
                    height: self.theme.metrics.pickerControl.disclosureSize
                )
                .accessibilityHidden(true)
        }
    }
}

struct SearchableProviderPicker: View {
    @Environment(\.theme) private var theme
    @Environment(\.datasheetPalette) private var datasheetPalette
    @Environment(\.isEnabled) private var isEnabled
    let builtInProviders: [(id: String, name: String)]
    let savedProviders: [SettingsStore.SavedProvider]
    @Binding var selectedProviderID: String
    let controlWidth: CGFloat
    let controlHeight: CGFloat?
    let appearance: SearchablePickerAppearance

    init(
        builtInProviders: [(id: String, name: String)],
        savedProviders: [SettingsStore.SavedProvider],
        selectedProviderID: Binding<String>,
        controlWidth: CGFloat = 180,
        controlHeight: CGFloat? = nil,
        appearance: SearchablePickerAppearance = .standard
    ) {
        self.builtInProviders = builtInProviders
        self.savedProviders = savedProviders
        self._selectedProviderID = selectedProviderID
        self.controlWidth = controlWidth
        self.controlHeight = controlHeight
        self.appearance = appearance
    }

    @State private var searchText = ""
    @State private var isShowingPopover = false

    private var allProviders: [(id: String, name: String, isBuiltIn: Bool)] {
        var result: [(id: String, name: String, isBuiltIn: Bool)] = []

        // Add built-in providers
        for provider in self.builtInProviders {
            result.append((id: provider.id, name: provider.name, isBuiltIn: true))
        }

        // Add saved providers
        for provider in self.savedProviders {
            result.append((id: provider.id, name: provider.name, isBuiltIn: false))
        }

        return result
    }

    private var filteredProviders: [(id: String, name: String, isBuiltIn: Bool)] {
        if self.searchText.isEmpty {
            return self.allProviders
        }
        return self.allProviders.filter {
            $0.name.localizedCaseInsensitiveContains(self.searchText) ||
                $0.id.localizedCaseInsensitiveContains(self.searchText)
        }
    }

    private var selectedProviderName: String {
        if let provider = allProviders.first(where: { $0.id == selectedProviderID }) {
            return provider.name
        }
        return self.selectedProviderID.isEmpty ? "Select Provider" : self.selectedProviderID
    }

    var body: some View {
        Button(action: { self.isShowingPopover.toggle() }) {
            HStack(spacing: 8) {
                if self.appearance == .datasheet {
                    Text(self.selectedProviderName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(self.isEnabled ? self.datasheetPalette.text : self.datasheetPalette.text2)
                } else {
                    Text(self.selectedProviderName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 6)
                SearchablePickerDisclosure(
                    appearance: self.appearance,
                    standardBackgroundOpacity: 0.7
                )
            }
            .modifier(SearchablePickerControlAppearance(
                appearance: self.appearance,
                width: self.controlWidth,
                height: self.controlHeight,
                usesMaterial: false,
                showsShadow: false
            ))
        }
        .buttonStyle(.plain)
        .popover(isPresented: self.$isShowingPopover, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search providers...", text: self.$searchText)
                        .textFieldStyle(.plain)
                }
                .searchablePickerSearchFieldChrome()

                Divider()

                // Provider list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Built-in section
                        let builtIns = self.filteredProviders.filter { $0.isBuiltIn }
                        if !builtIns.isEmpty {
                            Text("BUILT-IN")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.top, 8)
                                .padding(.bottom, 4)

                            ForEach(builtIns, id: \.id) { provider in
                                self.providerRow(provider)
                            }
                        }

                        // Saved/Custom section
                        let saved = self.filteredProviders.filter { !$0.isBuiltIn }
                        if !saved.isEmpty {
                            if !builtIns.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)
                            }

                            Text("CUSTOM")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.top, 4)
                                .padding(.bottom, 4)

                            ForEach(saved, id: \.id) { provider in
                                self.providerRow(provider)
                            }
                        }

                        if self.filteredProviders.isEmpty {
                            Text("No providers match '\(self.searchText)'")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .frame(width: 240)
        }
    }

    private func providerRow(_ provider: (id: String, name: String, isBuiltIn: Bool)) -> some View {
        Button(action: {
            self.selectedProviderID = provider.id
            self.searchText = ""
            self.isShowingPopover = false
        }) {
            HStack {
                Text(provider.name)
                    .lineLimit(1)
                Spacer()
                if provider.id == self.selectedProviderID {
                    Image(systemName: "checkmark")
                        .foregroundStyle(self.theme.palette.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .searchablePickerSelectedRowBackground(isSelected: provider.id == self.selectedProviderID)
    }
}

#Preview {
    SearchableProviderPicker(
        builtInProviders: [
            ("openai", "OpenAI"),
            ("groq", "Groq"),
            ("cerebras", "Cerebras"),
        ],
        savedProviders: [],
        selectedProviderID: .constant("openai")
    )
    .padding()
}
