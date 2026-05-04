import Foundation
import CoreData

extension TaskItem {
    var isDueToday: Bool {
        guard let d = dueDate else { return false }
        return Calendar.current.isDateInToday(d)
    }
}
