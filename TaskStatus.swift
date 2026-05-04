import Foundation

enum TaskStatus: Int16, CaseIterable, Identifiable {
    case todo = 0
    case doing = 1
    case done = 2

    var id: Int16 { rawValue }

    /// ✅ Traduction via Localizable.strings
    var title: String {
        switch self {
        case .todo:
            return NSLocalizedString("status.todo", comment: "Todo status")
        case .doing:
            return NSLocalizedString("status.doing", comment: "Doing status")
        case .done:
            return NSLocalizedString("status.done", comment: "Done status")
        }
    }
}
