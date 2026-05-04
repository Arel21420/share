import SwiftUI
import CoreData

struct NotesView: View {
    @Environment(\.managedObjectContext) private var ctx
    @EnvironmentObject private var persistence: PersistenceController
    @EnvironmentObject private var loc: LocalizationManager

    @State private var selectionID: NSManagedObjectID?
    @State private var query: String = ""
    @State private var showSettings = false

    // Tri CoreData: createdAt desc + id desc (tie-breaker stable)
    @FetchRequest private var notes: FetchedResults<NoteItem>

    init() {
        _notes = FetchRequest<NoteItem>(
            sortDescriptors: [
                NSSortDescriptor(key: "createdAt", ascending: false),
                NSSortDescriptor(key: "id", ascending: false) // UUID
            ],
            predicate: nil,
            animation: nil
        )
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectionID) {
                Section {
                    noteRows()
                } header: {
                    Text(loc.tr("notes.section.title"))
                }
            }
            .applyPlatformListStyle()
            .navigationTitle(loc.tr("tab.notes"))
            .searchable(text: $query, placement: .sidebar, prompt: Text(loc.tr("notes.search")))
            .transaction { $0.animation = nil }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: createNoteSafe) { Image(systemName: "plus") }
                        .keyboardShortcut("n", modifiers: [.command])
                        .help(Text(loc.tr("notes.new")))
                        .disabled(!persistence.isLoaded)

                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .help(Text(loc.tr("app.settings")))
                }
            }
            // ✅ important : stabilise l’ordre en rendant id/createdAt non-nil
            .onAppear { backfillStableSortFieldsIfNeeded() }
            .onChange(of: notes.count) { _, _ in
                backfillStableSortFieldsIfNeeded()
            }

        } detail: {
            if let selectionID,
               let note = try? ctx.existingObject(with: selectionID) as? NoteItem {
                NoteDetailView(note: note, selectionID: $selectionID)
                    .id(selectionID)
            } else {
                NotesEmptyView()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(loc)
        }
        .tint(.primary)
    }

    // MARK: - Rows

    @ViewBuilder
    private func noteRows() -> some View {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered: [NoteItem] = notes.filter { note in
            if q.isEmpty { return true }
            let hay = [
                effectiveTitle(for: note),
                (note.noteText ?? "")
            ].joined(separator: " ").lowercased()
            return hay.contains(q)
        }

        // ✅ IMPORTANT : identité stable = objectID
        ForEach(filtered, id: \.objectID) { note in
            NoteRow(note: note)
                .tag(note.objectID)
                .swipeDeleteActions {
                    delete(note)
                }
        }
    }

    private func effectiveTitle(for note: NoteItem) -> String {
        let typed = (note.typedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        let recognized = (note.recognizedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !recognized.isEmpty { return recognized }
        return ""
    }

    // MARK: - Backfill to stabilize sorting

    private func backfillStableSortFieldsIfNeeded() {
        guard persistence.isLoaded else { return }

        // On “répare” uniquement si nil (ou createdAt nil), sans toucher au reste.
        ctx.perform {
            var changed = false

            for n in notes {
                if n.id == nil {
                    n.id = UUID()
                    changed = true
                }

                if n.createdAt == nil {
                    // on préfère garder la logique: createdAt = première date connue
                    n.createdAt = n.updatedAt ?? Date()
                    changed = true
                }
            }

            guard changed else { return }

            do {
                try ctx.save()
            } catch {
                print("❌ backfillStableSortFieldsIfNeeded save error:", error)
            }
        }
    }

    // MARK: - CRUD

    private func createNoteSafe() {
        guard persistence.isLoaded else { return }
        ctx.perform {
            let n = NoteItem(context: ctx)
            n.id = UUID()
            n.createdAt = Date()
            n.updatedAt = Date()
            n.typedTitle = ""
            n.recognizedTitle = ""
            n.noteText = ""
            n.titleDrawingData = nil
            n.titleDrawingPreviewPNG = nil
            n.bodyDrawingData = nil
            n.bodyDrawingPreviewPNG = nil

            do {
                try ctx.save()
                DispatchQueue.main.async { selectionID = n.objectID }
            } catch {
                print("❌ createNote save error:", error)
            }
        }
    }

    private func delete(_ note: NoteItem) {
        guard persistence.isLoaded else { return }
        ctx.perform {
            if selectionID == note.objectID {
                DispatchQueue.main.async { selectionID = nil }
            }
            ctx.delete(note)
            do { try ctx.save() }
            catch { print("❌ delete note error:", error) }
        }
    }
}

// MARK: - Empty view

private struct NotesEmptyView: View {
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "note.text")
                .font(.system(size: 44, weight: .light))
            Text(loc.tr("notes.select"))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
    }
}

// MARK: - Helpers

private extension View {
    @ViewBuilder
    func swipeDeleteActions(onDelete: @escaping () -> Void) -> some View {
        #if os(iOS)
        self.swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .tint(.red)
        }
        #elseif os(macOS)
        if #available(macOS 13.0, *) {
            self.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .tint(.red)
            }
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func applyPlatformListStyle() -> some View {
        #if os(macOS)
        self.listStyle(.sidebar)
        #else
        self.listStyle(.insetGrouped)
        #endif
    }
}
