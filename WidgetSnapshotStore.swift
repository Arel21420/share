import Foundation

// MARK: - Snapshot model (partagé App + Widget)

struct DashboardSnapshot: Codable, Equatable {
    let todo: Int
    let doing: Int
    let done: Int
    let overdue: Int
    let dueToday: Int
    let updatedAt: Date

    static let placeholder = DashboardSnapshot(
        todo: 1,
        doing: 2,
        done: 1,
        overdue: 1,
        dueToday: 0,
        updatedAt: Date()
    )
}

// MARK: - Store (App Group)

enum WidgetSnapshotStore {

    /// ⚠️ DOIT être identique dans l’app + le widget
    static let appGroupID = "group.com.jololo.HandToDo"
    private static let key = "dashboard_snapshot_v1"

    // MARK: Load

    static func load() -> DashboardSnapshot {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = defaults.data(forKey: key)
        else {
            return .placeholder
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return (try? decoder.decode(DashboardSnapshot.self, from: data))
            ?? .placeholder
    }

    // MARK: Save

    static func save(_ snapshot: DashboardSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            assertionFailure("❌ App Group UserDefaults not available")
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(snapshot) else {
            assertionFailure("❌ Failed to encode DashboardSnapshot")
            return
        }

        // ⚠️ Important : UserDefaults est thread-safe,
        // mais on force le main pour cohérence WidgetKit
        DispatchQueue.main.async {
            defaults.set(data, forKey: key)
        }
    }
}
