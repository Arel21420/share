import Foundation
import CoreData
import WidgetKit

enum DashboardWidgetUpdater {

    /// Call this when data changes (after saves + remote changes)
    static func scheduleUpdate(using container: NSPersistentCloudKitContainer) {
        // Calcul en background pour ne pas bloquer l’UI
        let bg = container.newBackgroundContext()
        bg.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        bg.perform {
            let snap = computeSnapshot(in: bg)

            // On écrit dans l’App Group
            WidgetSnapshotStore.save(snap)

            // Puis on demande au widget de relire
            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private static func computeSnapshot(in ctx: NSManagedObjectContext) -> DashboardSnapshot {
        // ⚠️ Adapte "TaskItem" / "statusRaw" / "dueDate" si besoin,
        // mais chez toi ça ressemble à ça.

        func count(_ predicate: NSPredicate) -> Int {
            let req = NSFetchRequest<NSFetchRequestResult>(entityName: "TaskItem")
            req.predicate = predicate
            req.includesSubentities = false
            return (try? ctx.count(for: req)) ?? 0
        }

        let todo = count(NSPredicate(format: "statusRaw == %d", TaskStatus.todo.rawValue))
        let doing = count(NSPredicate(format: "statusRaw == %d", TaskStatus.doing.rawValue))
        let done  = count(NSPredicate(format: "statusRaw == %d", TaskStatus.done.rawValue))

        // overdue = dueDate < startOfToday && status != done
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let overdue = count(NSPredicate(format: "dueDate != nil AND dueDate < %@ AND statusRaw != %d",
                                        startOfToday as NSDate,
                                        TaskStatus.done.rawValue))

        // dueToday = dueDate in [startOfToday, startOfTomorrow) && status != done
        let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday)!
        let dueToday = count(NSPredicate(format: "dueDate != nil AND dueDate >= %@ AND dueDate < %@ AND statusRaw != %d",
                                         startOfToday as NSDate,
                                         startOfTomorrow as NSDate,
                                         TaskStatus.done.rawValue))

        return DashboardSnapshot(
            todo: todo,
            doing: doing,
            done: done,
            overdue: overdue,
            dueToday: dueToday,
            updatedAt: Date()
        )
    }
}
