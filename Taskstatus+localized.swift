import Foundation

// ✅ Extension pour localiser les titres des statuts
extension TaskStatus {
    /// Titre localisé du statut
    var localizedTitle: String {
        switch self {
        case .todo:
            return NSLocalizedString("status.todo", comment: "")
        case .doing:
            return NSLocalizedString("status.doing", comment: "")
        case .done:
            return NSLocalizedString("status.done", comment: "")
        }
    }
}
