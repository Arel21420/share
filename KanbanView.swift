import SwiftUI
import CoreData
import UniformTypeIdentifiers

/// ✨ KanbanView REDESIGNED - Version WOW avec gradients
/// ✅ Conserve drag & drop et toutes les fonctionnalités
struct KanbanView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var persistence: PersistenceController
    
    @Binding var isPresented: Bool
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(key: "dueDate", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ],
        animation: .snappy
    )
    private var tasks: FetchedResults<TaskItem>
    
    @State private var selectedTask: TaskItem?
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 16) {
                        kanbanColumn(status: .todo, width: columnWidth(for: geo.size))
                        kanbanColumn(status: .doing, width: columnWidth(for: geo.size))
                        kanbanColumn(status: .done, width: columnWidth(for: geo.size))
                    }
                    .padding(16)
                }
            }
            .background(LinearGradient.backgroundGradient(colorScheme))
            #if os(macOS)
            .frame(minWidth: 1000, minHeight: 700)
            #else
            .navigationTitle(loc.tr("view.kanban"))
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // ✨ Close button avec gradient
                    Button {
                        isPresented = false
                    } label: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.primaryGradient)
                                .frame(width: 32, height: 32)
                                .shadow(color: Color.primaryStart.opacity(0.3), radius: 6, y: 2)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task, selectionID: .constant(nil))
            }
        }
    }
    
    private func columnWidth(for size: CGSize) -> CGFloat {
        #if os(macOS)
        let availableWidth = size.width - 48
        let columnWidth = availableWidth / 3
        return max(280, min(columnWidth, 360))
        #else
        let availableWidth = size.width - 48
        
        if size.width > 900 {
            // iPad landscape - 3 colonnes
            let columnWidth = (availableWidth / 3) - 10
            return max(290, columnWidth)
        } else if size.width > 600 {
            // iPad portrait - 2 colonnes
            return (availableWidth / 2) - 10
        } else {
            // iPhone - 1 colonne
            return availableWidth
        }
        #endif
    }
    
    // ✨ Kanban Column avec gradient
    private func kanbanColumn(status: TaskStatus, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // ✨ Header avec gradient
            HStack(spacing: 12) {
                // Icon gradient
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(statusGradient(for: status))
                        .frame(width: 40, height: 40)
                        .shadow(color: statusGradient(for: status).shadowColor, radius: 8, y: 4)
                    
                    Image(systemName: statusIcon(for: status))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                Text(status.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.primaryText(colorScheme))
                
                Spacer()
                
                // Count badge gradient
                Text("\(tasksForStatus(status).count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusGradient(for: status))
                    .clipShape(Capsule())
                    .shadow(color: statusGradient(for: status).shadowColor, radius: 6, y: 2)
            }
            .padding(16)
            
            Divider()
                .background(Color.secondaryText(colorScheme).opacity(0.2))
            
            // Tasks list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(tasksForStatus(status)) { task in
                        KanbanCard(task: task)
                            .onTapGesture {
                                selectedTask = task
                            }
                            .onDrag {
                                NSItemProvider(object: task.objectID.uriRepresentation().absoluteString as NSString)
                            }
                            .onDrop(of: [.text], delegate: KanbanDropDelegate(
                                task: task,
                                targetStatus: status,
                                ctx: ctx
                            ))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.secondaryBackground(colorScheme))
                .shadow(
                    color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.08),
                    radius: 16,
                    y: 8
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(statusGradient(for: status).shadowColor, lineWidth: 1)
        )
        // ✅ onDrop sur toute la colonne (espace vide inclus)
        .onDrop(of: [.text], delegate: KanbanColumnDropDelegate(
            targetStatus: status,
            ctx: ctx
        ))
    }
    
    private func statusGradient(for status: TaskStatus) -> LinearGradient {
        switch status {
        case .todo: return .todoGradient
        case .doing: return .doingGradient
        case .done: return .doneGradient
        }
    }
    
    private func statusIcon(for status: TaskStatus) -> String {
        switch status {
        case .todo: return "circle"
        case .doing: return "bolt.fill"
        case .done: return "checkmark.circle.fill"
        }
    }
    
    private func tasksForStatus(_ status: TaskStatus) -> [TaskItem] {
        tasks.filter { $0.status == status }
    }
}

// MARK: - Kanban Card (REDESIGNED)

private struct KanbanCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var task: TaskItem
    @EnvironmentObject private var loc: LocalizationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            titleView
                .lineLimit(2)
            
            // Due date
            if let dueDate = task.dueDate {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(task.isOverdue ? LinearGradient.urgentGradient : LinearGradient.todoGradient)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: task.isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    Text(dueDate.compactRelativeFormat())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(task.isOverdue ? Color.urgentStart : Color.secondaryText(colorScheme))
                }
            }
            
            // Color indicator
            if task.color != .none, let c = task.color.uiColor {
                HStack {
                    Circle()
                        .fill(Color(c))
                        .frame(width: 10, height: 10)
                        .shadow(color: Color(c).opacity(0.5), radius: 4, y: 2)
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardBackground(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    task.isOverdue ? Color.urgentStart.opacity(0.3) : Color.primaryText(colorScheme).opacity(0.05),
                    lineWidth: 2
                )
        )
        .shadow(
            color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.06),
            radius: 8,
            y: 4
        )
    }
    
    @ViewBuilder
    private var titleView: some View {
        #if os(iOS)
        if shouldShowHandwrittenTitle, let data = task.titleDrawingData, !data.isEmpty {
            HandwrittenTitleRowView(drawingData: data, height: 28)
        } else {
            Text(task.effectiveTitle.isEmpty ? "—" : task.effectiveTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primaryText(colorScheme))
        }
        #elseif os(macOS)
        if shouldShowHandwrittenTitle, let png = task.titleDrawingPreviewPNG, let nsImage = NSImage(data: png) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 28)
        } else {
            Text(task.effectiveTitle.isEmpty ? "—" : task.effectiveTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primaryText(colorScheme))
        }
        #else
        Text(task.effectiveTitle.isEmpty ? "—" : task.effectiveTitle)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.primaryText(colorScheme))
        #endif
    }
    
    private var shouldShowHandwrittenTitle: Bool {
        let typed = (task.typedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard typed.isEmpty else { return false }
        
        #if os(iOS)
        return (task.titleDrawingData?.isEmpty == false)
        #elseif os(macOS)
        return (task.titleDrawingPreviewPNG?.isEmpty == false)
        #else
        return false
        #endif
    }
}

// MARK: - Drop Delegate (UNCHANGED - preserve drag & drop)

private struct KanbanDropDelegate: DropDelegate {
    let task: TaskItem
    let targetStatus: TaskStatus
    let ctx: NSManagedObjectContext
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        itemProvider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let uriString = String(data: data, encoding: .utf8),
                  let url = URL(string: uriString),
                  let objectID = ctx.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url),
                  let draggedTask = try? ctx.existingObject(with: objectID) as? TaskItem else {
                return
            }
            
            DispatchQueue.main.async {
                ctx.perform {
                    draggedTask.status = targetStatus
                    do {
                        try ctx.save()
                        WidgetBridge.reloadDashboard()
                    } catch {
                        print("❌ Drop save error:", error)
                    }
                }
            }
        }
        
        return true
    }
}

// MARK: - Column Drop Delegate (pour espace vide)

private struct KanbanColumnDropDelegate: DropDelegate {
    let targetStatus: TaskStatus
    let ctx: NSManagedObjectContext
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        itemProvider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let uriString = String(data: data, encoding: .utf8),
                  let url = URL(string: uriString),
                  let objectID = ctx.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url),
                  let draggedTask = try? ctx.existingObject(with: objectID) as? TaskItem else {
                return
            }
            
            DispatchQueue.main.async {
                ctx.perform {
                    draggedTask.status = targetStatus
                    do {
                        try ctx.save()
                        WidgetBridge.reloadDashboard()
                    } catch {
                        print("❌ Drop save error:", error)
                    }
                }
            }
        }
        
        return true
    }
}
