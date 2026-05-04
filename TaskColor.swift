import SwiftUI

enum TaskColor: Int16, CaseIterable, Identifiable {
    case none = 0
    case orange = 1
    case red = 2

    var id: Int16 { rawValue }

    var title: String {
        switch self {
        case .none: return "Aucun"
        case .orange: return "Orange"
        case .red: return "Rouge"
        }
    }

    var uiColor: Color? {
        switch self {
        case .none: return nil
        case .orange: return .orange
        case .red: return .red
        }
    }
}
