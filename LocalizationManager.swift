import Foundation
import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case fr = "fr"
    case en = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Système"
        case .fr: return "Français"
        case .en: return "English"
        }
    }

    var locale: Locale {
        switch self {
        case .system: return .current
        case .fr: return Locale(identifier: "fr")
        case .en: return Locale(identifier: "en")
        }
    }

    var lproj: String? {
        switch self {
        case .system: return nil
        case .fr: return "fr"
        case .en: return "en"
        }
    }
}

final class LocalizationManager: ObservableObject {
    @AppStorage("appLanguage") private var stored: String = AppLanguage.system.rawValue {
        didSet { objectWillChange.send() }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: stored) ?? .system }
        set { stored = newValue.rawValue }
    }

    /// ✅ Bundle utilisé pour les traductions
    var bundle: Bundle {
        guard let lproj = language.lproj,
              let path = Bundle.main.path(forResource: lproj, ofType: "lproj"),
              let b = Bundle(path: path) else {
            return .main
        }
        return b
    }

    /// ✅ Traduction robuste (retourne la clé si manquante)
    func tr(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }
}
