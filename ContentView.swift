import SwiftUI
import CoreData

/// âœ¨ ContentView REDESIGNED - Version WOW avec gradients
/// âœ… Conserve TOUTE la logique mÃ©tier existante
struct ContentView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var persistence: PersistenceController
    @EnvironmentObject private var loc: LocalizationManager

    // MARK: - Tabs

    private enum MainTab: String, CaseIterable {
        case tasks
        case notes
    }

    @State private var tab: MainTab = .tasks

    // MARK: - Selection

    @State private var taskSelectionID: NSManagedObjectID?
    @State private var noteSelectionID: NSManagedObjectID?

    // MARK: - UI State

    @State private var query: String = ""
    @State private var showSettings = false
    @State private var filter: TaskFilter = .all

    @State private var showKanban = false
    @State private var showCalendar = false

    // âœ… NOUVEAU: Confirmations de suppression
    @State private var taskPendingDelete: TaskItem?
    @State private var notePendingDelete: NoteItem?
    
    // MARK: - Fetch

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(key: "statusRaw", ascending: true),
            NSSortDescriptor(key: "dueDate", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ],
        animation: .snappy
    )
    private var tasks: FetchedResults<TaskItem>

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ],
        animation: .snappy
    )
    private var notes: FetchedResults<NoteItem>

    // MARK: - Body

    var body: some View {
        mainView
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(loc)
            }
            // ✅ KANBAN : fullScreenCover sur iOS pour plein écran iPad
            #if os(iOS)
            .fullScreenCover(isPresented: $showKanban) {
                KanbanView(isPresented: $showKanban)
                    .environment(\.managedObjectContext, ctx)
                    .environmentObject(loc)
            }
            #else
            .sheet(isPresented: $showKanban) {
                KanbanView(isPresented: $showKanban)
                    .environment(\.managedObjectContext, ctx)
                    .environmentObject(loc)
                    .frame(minWidth: 1200, minHeight: 900)
            }
            #endif
            // ✅ CALENDAR : fullScreenCover sur iOS pour plein écran iPad
            #if os(iOS)
            .fullScreenCover(isPresented: $showCalendar) {
                CalendarView(isPresented: $showCalendar)
                    .environment(\.managedObjectContext, ctx)
                    .environmentObject(loc)
            }
            #else
            .sheet(isPresented: $showCalendar) {
                CalendarView(isPresented: $showCalendar)
                    .environment(\.managedObjectContext, ctx)
                    .environmentObject(loc)
                    .frame(minWidth: 1100, minHeight: 900)
            }
            #endif
            .tint(.primary)
            .onChange(of: tab) { _ in
                query = ""
            }
            // âœ… NOUVEAU: Alertes de confirmation de suppression
            .alert("Supprimer cette tÃ¢che ?", isPresented: Binding(
                get: { taskPendingDelete != nil },
                set: { if !$0 { taskPendingDelete = nil } }
            )) {
                Button(loc.tr("common.cancel"), role: .cancel) {
                    taskPendingDelete = nil
                }
                Button(loc.tr("common.delete"), role: .destructive) {
                    if let task = taskPendingDelete {
                        confirmDeleteTask(task)
                    }
                    taskPendingDelete = nil
                }
            } message: {
                Text("Cette action est irrÃ©versible.")
            }
            .alert("Supprimer cette note ?", isPresented: Binding(
                get: { notePendingDelete != nil },
                set: { if !$0 { notePendingDelete = nil } }
            )) {
                Button(loc.tr("common.cancel"), role: .cancel) {
                    notePendingDelete = nil
                }
                Button(loc.tr("common.delete"), role: .destructive) {
                    if let note = notePendingDelete {
                        confirmDeleteNote(note)
                    }
                    notePendingDelete = nil
                }
            } message: {
                Text("Cette action est irrÃ©versible.")
            }
    }

    private var mainView: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 380, ideal: 500, max: 650)  // ✅ Plus large (420→500)
        #endif
    }

    // MARK: - Sidebar (REDESIGNED)

    private var sidebar: some View {
        List(selection: selectionBinding) {

            // âœ¨ Segmented header avec gradient background
            Section {
                Picker("", selection: $tab) {
                    Text(loc.tr("tab.tasks")).tag(MainTab.tasks)
                    Text(loc.tr("tab.notes")).tag(MainTab.notes)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }

            switch tab {
            case .tasks:
                Section {
                    taskRows(status: .todo)
                } header: {
                    sectionHeader(
                        icon: "circle",
                        title: loc.tr("status.todo"),
                        gradient: LinearGradient.todoGradient,
                        count: tasks.filter { $0.status == .todo }.count
                    )
                }

                Section {
                    taskRows(status: .doing)
                } header: {
                    sectionHeader(
                        icon: "bolt.fill",
                        title: loc.tr("status.doing"),
                        gradient: LinearGradient.doingGradient,
                        count: tasks.filter { $0.status == .doing }.count
                    )
                }

                Section {
                    taskRows(status: .done)
                } header: {
                    sectionHeader(
                        icon: "checkmark.circle.fill",
                        title: loc.tr("status.done"),
                        gradient: LinearGradient.doneGradient,
                        count: tasks.filter { $0.status == .done }.count
                    )
                }

            case .notes:
                Section {
                    noteRows()
                } header: {
                    sectionHeader(
                        icon: "note.text",
                        title: loc.tr("notes.section.title"),
                        gradient: LinearGradient.primaryGradient,
                        count: notes.count
                    )
                }
            }
        }
        .applyPlatformListStyle()
        .scrollContentBackground(.hidden)
        .background(LinearGradient.backgroundGradient(colorScheme))
        .navigationTitle(loc.tr("app.title"))
        .searchable(
            text: $query,
            placement: .sidebar,
            prompt: Text(tab == .tasks ? loc.tr("app.search") : loc.tr("notes.search"))
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: primaryCreateAction) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(LinearGradient.primaryGradient)
                        .clipShape(Circle())
                        .shadow(color: Color.primaryStart.opacity(0.3), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: [.command])
                .help(Text(tab == .tasks ? loc.tr("app.newTask") : loc.tr("notes.new")))
                .disabled(!persistence.isLoaded)

                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .help(Text(loc.tr("app.settings")))

                syncStatusIndicator
            }
        }
    }

    // âœ¨ Section Header avec icÃ´ne gradient
    private func sectionHeader(icon: String, title: String, gradient: LinearGradient, count: Int) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(gradient)
                    .frame(width: 28, height: 28)
                    .shadow(color: gradient.shadowColor, radius: 4, y: 2)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.primaryText(colorScheme))

            Spacer()

            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(gradient)
                .clipShape(Capsule())
                .shadow(color: gradient.shadowColor, radius: 4, y: 2)
        }
        .padding(.vertical, 6)
    }

    private var selectionBinding: Binding<NSManagedObjectID?> {
        Binding(
            get: {
                switch tab {
                case .tasks: return taskSelectionID
                case .notes: return noteSelectionID
                }
            },
            set: { newValue in
                switch tab {
                case .tasks:
                    taskSelectionID = newValue
                case .notes:
                    noteSelectionID = newValue
                }
            }
        )
    }

    private func primaryCreateAction() {
        switch tab {
        case .tasks: createTaskSafe()
        case .notes: createNoteSafe()
        }
    }

    // âœ¨ Sync indicator redesignÃ©
    @ViewBuilder
    private var syncStatusIndicator: some View {
        if persistence.isSyncing {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                #if os(macOS)
                Text(loc.tr("sync.syncing"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
            }
            .help(Text(loc.tr("sync.syncing")))
        } else if persistence.lastSyncError != nil {
            Button {
                // TODO: Afficher dÃ©tails de l'erreur
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .help(Text(loc.tr("sync.error")))
        }
    }

    // MARK: - Detail (REDESIGNED)

    @ViewBuilder
    private var detail: some View {
        switch tab {
        case .tasks:
            if let id = taskSelectionID,
               let task = try? ctx.existingObject(with: id) as? TaskItem {
                TaskDetailView(task: task, selectionID: $taskSelectionID)
                    .id(id)
            } else {
                DashboardView(
                    todoCount: todoCount,
                    doingCount: doingCount,
                    doneCount: doneCount,
                    overdueCount: overdueCount,
                    selectedFilter: filter,
                    onSelect: { f in
                        filter = f
                        taskSelectionID = nil
                    },
                    onClearFilter: {
                        filter = .all
                        taskSelectionID = nil
                    },
                    onShowKanban: { showKanban = true },
                    onShowCalendar: { showCalendar = true }
                )
            }

        case .notes:
            if let id = noteSelectionID,
               let note = try? ctx.existingObject(with: id) as? NoteItem {
                NoteDetailView(note: note, selectionID: $noteSelectionID)
                    .id(id)
            } else {
                NotesEmptyView()
            }
        }
    }

    // MARK: - Task Rows

    @ViewBuilder
    private func taskRows(status: TaskStatus) -> some View {
        let filtered = tasks
            .filter { $0.status == status }
            .filter { matchesQuery($0) }
            .filter { matchesFilter($0) }
            .sorted { a, b in
                if a.sortDueKey != b.sortDueKey { return a.sortDueKey < b.sortDueKey }
                return (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast)
            }

        ForEach(filtered) { task in
            TaskRow(
                task: task,
                isSelected: taskSelectionID == task.objectID
            )
            .tag(task.objectID)
            .swipeDeleteActions {
                // âœ… Demande confirmation au lieu de supprimer directement
                taskPendingDelete = task
            }
        }
        
    }

    private func matchesQuery(_ task: TaskItem) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return true }
        let hay = [
            task.effectiveTitle,
            (task.noteText ?? "")
        ].joined(separator: " ").lowercased()
        return hay.contains(q.lowercased())
    }

    private func matchesFilter(_ task: TaskItem) -> Bool {
        switch filter {
        case .all: return true
        case .todo: return task.status == .todo
        case .doing: return task.status == .doing
        case .done: return task.status == .done
        case .overdue: return task.isOverdue
        }
    }

    // MARK: - Note Rows

    @ViewBuilder
    private func noteRows() -> some View {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = notes.filter { note in
            if q.isEmpty { return true }
            let hay = [
                note.effectiveTitle,
                (note.noteText ?? "")
            ].joined(separator: " ").lowercased()
            return hay.contains(q)
        }

        ForEach(filtered, id: \.objectID) { note in
            NoteRow(
                note: note,
                isSelected: noteSelectionID == note.objectID
            )
            .tag(note.objectID)
            .swipeDeleteActions {
                // âœ… Demande confirmation au lieu de supprimer directement
                notePendingDelete = note
            }
        }
    }

    // MARK: - Counts

    private var todoCount: Int { tasks.filter { $0.status == .todo }.count }
    private var doingCount: Int { tasks.filter { $0.status == .doing }.count }
    private var doneCount: Int { tasks.filter { $0.status == .done }.count }
    private var overdueCount: Int { tasks.filter { $0.isOverdue }.count }

    // MARK: - Actions (Tasks)

    private func createTaskSafe() {
        guard persistence.isLoaded else { return }
        ctx.perform {
            let t = TaskItem(context: ctx)
            t.id = UUID()
            t.createdAt = Date()
            t.updatedAt = Date()
            t.typedTitle = ""
            t.recognizedTitle = ""
            t.noteText = t.noteText ?? ""
            t.statusRaw = TaskStatus.todo.rawValue
            t.colorRaw = TaskColor.none.rawValue

            do {
                try ctx.save()
                WidgetBridge.reloadDashboard()
                DispatchQueue.main.async { taskSelectionID = t.objectID }
            } catch {
                print("âŒ createTask save error:", error)
            }
        }
    }

    /// âœ… Suppression aprÃ¨s confirmation
    private func confirmDeleteTask(_ task: TaskItem) {
        guard persistence.isLoaded else { return }
        ctx.perform {
            if taskSelectionID == task.objectID {
                DispatchQueue.main.async { taskSelectionID = nil }
            }
            ctx.delete(task)
            do {
                try ctx.save()
                WidgetBridge.reloadDashboard()
            } catch {
                print("âŒ delete error:", error)
            }
        }
    }

    // MARK: - Actions (Notes)

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

            do {
                try ctx.save()
                DispatchQueue.main.async { noteSelectionID = n.objectID }
            } catch {
                print("âŒ createNote save error:", error)
            }
        }
    }

    /// âœ… Suppression aprÃ¨s confirmation
    private func confirmDeleteNote(_ note: NoteItem) {
        guard persistence.isLoaded else { return }
        ctx.perform {
            if noteSelectionID == note.objectID {
                DispatchQueue.main.async { noteSelectionID = nil }
            }
            ctx.delete(note)
            do {
                try ctx.save()
            } catch {
                print("âŒ delete note error:", error)
            }
        }
    }
}

// MARK: - Dashboard (REDESIGNED)

private enum TaskFilter: Equatable { case all, todo, doing, done, overdue }

private struct DashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var loc: LocalizationManager

    let todoCount: Int
    let doingCount: Int
    let doneCount: Int
    let overdueCount: Int

    let selectedFilter: TaskFilter
    let onSelect: (TaskFilter) -> Void
    let onClearFilter: () -> Void
    let onShowKanban: () -> Void
    let onShowCalendar: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // âœ¨ View buttons avec gradient
                HStack(spacing: 16) {
                    viewButton(
                        icon: "square.grid.2x2",
                        title: loc.tr("view.kanban"),
                        gradient: LinearGradient.primaryGradient,
                        action: onShowKanban
                    )

                    viewButton(
                        icon: "calendar",
                        title: loc.tr("view.calendar"),
                        gradient: LinearGradient.todoGradient,
                        action: onShowCalendar
                    )
                }
                .padding(.horizontal, 24)

                // âœ¨ Icon et titre
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.primaryGradient)
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.primaryStart.opacity(0.3), radius: 16, y: 8)

                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.white)
                    }

                    Text(loc.tr("dashboard.selectTask"))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.primaryText(colorScheme))
                }
                .padding(.vertical, 12)

                // âœ¨ Stats cards avec gradients
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        statCard(
                            title: loc.tr("status.todo"),
                            value: "\(todoCount)",
                            filter: .todo,
                            gradient: LinearGradient.todoGradient,
                            icon: "circle"
                        )
                        statCard(
                            title: loc.tr("status.doing"),
                            value: "\(doingCount)",
                            filter: .doing,
                            gradient: LinearGradient.doingGradient,
                            icon: "bolt.fill"
                        )
                    }

                    HStack(spacing: 16) {
                        statCard(
                            title: loc.tr("status.done"),
                            value: "\(doneCount)",
                            filter: .done,
                            gradient: LinearGradient.doneGradient,
                            icon: "checkmark.circle.fill"
                        )

                        statCard(
                            title: loc.tr("dashboard.overdue"),
                            value: "\(overdueCount)",
                            filter: .overdue,
                            gradient: overdueGradient,
                            icon: "exclamationmark.triangle.fill"
                        )
                    }
                }
                .frame(maxWidth: 600)
                .padding(.horizontal, 24)

                if selectedFilter != .all {
                    Button(loc.tr("dashboard.clearFilter")) { onClearFilter() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(LinearGradient.primaryGradient)
                        .clipShape(Capsule())
                        .shadow(color: Color.primaryStart.opacity(0.3), radius: 8, y: 4)
                }
            }
            .padding(.vertical, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient.backgroundGradient(colorScheme))
    }

    // âœ… Computed property pour le gradient overdue
    private var overdueGradient: LinearGradient {
        #if os(iOS)
        return LinearGradient.urgentGradient // Toujours rouge sur iOS
        #else
        return overdueCount > 0 ? LinearGradient.urgentGradient : LinearGradient.doneGradient
        #endif
    }

    // âœ¨ View button moderne
    private func viewButton(icon: String, title: String, gradient: LinearGradient, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(gradient)
                        .frame(width: 40, height: 40)
                        .shadow(color: gradient.shadowColor, radius: 6, y: 2)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.primaryText(colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cardBackground(colorScheme))
                    .shadow(
                        color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.06),
                        radius: 12,
                        y: 4
                    )
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(scale: 1.03, shadowRadius: 20)
    }

    // âœ¨ Stat card avec gradient
    private func statCard(title: String, value: String, filter: TaskFilter, gradient: LinearGradient, icon: String) -> some View {
        Button { onSelect(filter) } label: {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(gradient)
                        .frame(width: 56, height: 56)
                        .shadow(color: gradient.shadowColor, radius: 12, y: 6)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(value)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Color.primaryText(colorScheme))

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.secondaryText(colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.cardBackground(colorScheme))
                    .shadow(
                        color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.08),
                        radius: 12,
                        y: 4
                    )
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(scale: 1.05, shadowRadius: 24)
    }
}

// MARK: - Notes empty (REDESIGNED)

private struct NotesEmptyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient.primaryGradient)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.primaryStart.opacity(0.3), radius: 16, y: 8)

                Image(systemName: "note.text")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white)
            }

            Text(loc.tr("notes.select"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primaryText(colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient.backgroundGradient(colorScheme))
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
