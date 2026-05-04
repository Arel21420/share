import Foundation
import CoreData
import Combine

@MainActor
final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    private let modelName = "HandToDo"
    private let cloudKitContainerId = "iCloud.com.jololo.HandToDo"

    let container: NSPersistentCloudKitContainer

    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var loadError: Error?
    
    // âœ… NOUVEAU : Indicateur de sync CloudKit
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncError: Error?

    private var didStartLoading = false

    // âœ… Coalesce remote changes (Ã©vite spam + UI instable)
    private var remoteChangeWorkItem: DispatchWorkItem?
    private var didInstallRemoteObserver = false
    private var didInstallSaveObserver = false
    
    // âœ… NOUVEAU : Observer les Ã©vÃ©nements CloudKit
    private var didInstallCloudKitObservers = false

    private init() {
        container = NSPersistentCloudKitContainer(name: modelName)

        if let description = container.persistentStoreDescriptions.first {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: cloudKitContainerId
            )
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        // âœ… AMÃ‰LIORÃ‰ : Meilleure merge policy (garde le plus rÃ©cent par propriÃ©tÃ©)
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.transactionAuthor = "HandToDo"
    }

    /// Charge le store en arriÃ¨re-plan (sans bloquer l'UI).
    func loadIfNeeded() {
        guard !didStartLoading else { return }
        didStartLoading = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }

            self.container.loadPersistentStores { storeDescription, error in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }

                    if let error {
                        self.loadError = error
                        self.isLoaded = false
                        print("âŒ loadPersistentStores error:", error)
                        return
                    }

                    self.loadError = nil
                    self.isLoaded = true

                    print("âœ… Loaded store:", storeDescription.url?.absoluteString ?? "nil")
                    print("âœ… CloudKit container:", self.cloudKitContainerId)

                    // âœ… Observers installÃ©s uniquement quand le store est prÃªt
                    self.installRemoteChangeObserver()
                    self.installViewContextSaveObserver()
                    self.installCloudKitObservers()

                    // âœ… OPTIMISATION : Widget update diffÃ©rÃ© pour ne pas ralentir le dÃ©marrage
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        DashboardWidgetUpdater.scheduleUpdate(using: self.container)
                    }
                }
            }
        }
    }

    // MARK: - Observe local saves (CRUCIAL pour update widget)

    private func installViewContextSaveObserver() {
        guard !didInstallSaveObserver else { return }
        didInstallSaveObserver = true

        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: container.viewContext,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            
            // âœ… AMÃ‰LIORÃ‰ : Ne reload le widget que si les donnÃ©es pertinentes ont changÃ©
            guard let userInfo = notification.userInfo else { return }
            
            let hasTaskChanges = self.hasRelevantTaskChanges(in: userInfo)
            
            if hasTaskChanges {
                DashboardWidgetUpdater.scheduleUpdate(using: self.container)
            }
        }
    }
    
    // âœ… NOUVEAU : DÃ©tecte si les changements affectent le widget
    private func hasRelevantTaskChanges(in userInfo: [AnyHashable: Any]) -> Bool {
        let inserted = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let deleted = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
        let updated = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        
        // Si insertion/suppression de TaskItem => reload
        if !inserted.isEmpty || !deleted.isEmpty {
            return inserted.contains(where: { $0 is TaskItem }) ||
                   deleted.contains(where: { $0 is TaskItem })
        }
        
        // Si update de status/dueDate => reload
        for obj in updated {
            guard let task = obj as? TaskItem else { continue }
            let changedKeys = task.changedValues().keys
            if changedKeys.contains("statusRaw") || changedKeys.contains("dueDate") {
                return true
            }
        }
        
        return false
    }

    // MARK: - Remote Change Handling (CloudKit)

    private func installRemoteChangeObserver() {
        guard !didInstallRemoteObserver else { return }
        didInstallRemoteObserver = true

        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: nil // âš ï¸ peut arriver hors-main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleRemoteChange()
            }
        }
    }

    /// Coalesce les notifications pour Ã©viter les refresh en boucle.
    @MainActor
    private func handleRemoteChange() {
        remoteChangeWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }

            print("â˜ï¸ NSPersistentStoreRemoteChange (coalesced)")

            // âœ… Widget refresh
            DashboardWidgetUpdater.scheduleUpdate(using: self.container)

            // âœ… OPTIMISATION : Pas de refreshAllObjects() - automaticallyMergesChangesFromParent suffit
            // Les changements CloudKit sont dÃ©jÃ  mergÃ©s automatiquement
        }

        remoteChangeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }
    
    // MARK: - CloudKit Sync Status (NOUVEAU)
    
    private func installCloudKitObservers() {
        guard !didInstallCloudKitObservers else { return }
        didInstallCloudKitObservers = true
        
        // âœ… DÃ©tecte quand CloudKit commence Ã  sync
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentCloudKitContainerEventChangedNotification"),
            object: container,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudKitEvent(notification)
        }
    }
    
    @MainActor
    private func handleCloudKitEvent(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let eventType = userInfo["eventType"] as? String else { return }
        
        switch eventType {
        case "setup":
            print("â˜ï¸ CloudKit: Setup")
            
        case "import":
            print("â˜ï¸ CloudKit: Import started")
            isSyncing = true
            
        case "export":
            print("â˜ï¸ CloudKit: Export started")
            isSyncing = true
            
        default:
            break
        }
        
        // âœ… DÃ©tecte les erreurs CloudKit
        if let error = userInfo["error"] as? Error {
            print("âŒ CloudKit error:", error.localizedDescription)
            lastSyncError = error
            isSyncing = false
        }
        
        // âœ… DÃ©tecte la fin de sync
        if let succeeded = userInfo["succeeded"] as? Bool, succeeded {
            print("âœ… CloudKit sync succeeded")
            isSyncing = false
            lastSyncError = nil
        }
    }
}
