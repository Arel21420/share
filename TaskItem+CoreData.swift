import Foundation
import CoreData

// ✅ Extension pour gérer automatiquement createdAt/updatedAt
extension TaskItem {
    
    /// ✅ Appelé automatiquement par Core Data avant chaque save
    /// ⚠️ nonisolated car c'est ainsi dans NSManagedObject
    nonisolated public override func willSave() {
        super.willSave()
        
        // ✅ CRITIQUE : createdAt ne doit être défini QU'À LA CRÉATION
        // Pas quand CloudKit sync l'objet !
        if isInserted {
            setPrimitiveValue(createdAt ?? Date(), forKey: "createdAt")
            setPrimitiveValue(updatedAt ?? Date(), forKey: "updatedAt")
            
            // ✅ Génère un UUID si manquant
            if id == nil {
                setPrimitiveValue(UUID(), forKey: "id")
            }
        }
        
        // ✅ Toujours mettre à jour updatedAt (sauf si supprimé ou si c'est une sync CloudKit)
        else if !isDeleted {
            let changed = changedValues()
            if !changed.isEmpty {
                // ✅ Ne pas toucher updatedAt si c'est juste CloudKit qui sync
                let changedKeys = Set(changed.keys)
                let metadataKeys: Set<String> = ["createdAt", "updatedAt", "id"]
                
                // Si on a changé autre chose que les metadata
                if !changedKeys.isSubset(of: metadataKeys) {
                    setPrimitiveValue(Date(), forKey: "updatedAt")
                }
            }
        }
    }
    
    /// ✅ Validation avant save
    /// ⚠️ nonisolated car c'est ainsi dans NSManagedObject
    nonisolated public override func validateForInsert() throws {
        try super.validateForInsert()
        
        // ✅ Assure qu'on a toujours un UUID
        if id == nil {
            setPrimitiveValue(UUID(), forKey: "id")
        }
    }
}
