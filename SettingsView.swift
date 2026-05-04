import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(loc.tr("settings.language"))) {
                    Picker(loc.tr("settings.language"), selection: Binding(
                        get: { loc.language },
                        set: { loc.language = $0 }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.title).tag(lang)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle(loc.tr("settings.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.tr("common.ok")) { dismiss() }
                }
            }
        }
    }
}
