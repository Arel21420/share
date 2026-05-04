import Foundation

extension TaskItem {
    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set { statusRaw = newValue.rawValue }
    }

    var color: TaskColor {
        get { TaskColor(rawValue: colorRaw) ?? .none }
        set { colorRaw = newValue.rawValue }
    }

    var effectiveTitle: String {
        let t = (typedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        return (recognizedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var sortDueKey: Date {
        dueDate ?? .distantFuture
    }

    var isOverdue: Bool {
        guard status != .done else { return false }
        guard let dueDate else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }
}
