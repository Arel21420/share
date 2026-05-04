import SwiftUI
import CoreData
#if os(macOS)
import AppKit
#endif

/// âœ¨ TaskDetailView REDESIGNED - Version WOW avec gradients
/// âœ… Conserve TOUTES les fonctionnalitÃ©s existantes (manuscrit, OCR, dates, etc.)
struct TaskDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var loc: LocalizationManager

    @ObservedObject var task: TaskItem
    @Binding var selectionID: NSManagedObjectID?

    @StateObject private var vm: TaskDetailViewModel

    @State private var confirmClearTitle = false
    @State private var confirmClearBody = false

    init(task: TaskItem, selectionID: Binding<NSManagedObjectID?>) {
        self.task = task
        self._selectionID = selectionID
        _vm = StateObject(wrappedValue: TaskDetailViewModel(ctx: task.managedObjectContext!, task: task))
    }

    private var canEditHandwriting: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    private var canShowHandwritingPreview: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    private var typedTitleBinding: Binding<String> {
        Binding(
            get: { vm.typedTitle },
            set: { vm.setTypedTitleFromUser($0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard

                if canEditHandwriting || canShowHandwritingPreview {
                    titleHandwritingCard
                    bodyHandwritingCard
                }
            }
            .padding(20)
        }
        .background(LinearGradient.backgroundGradient(colorScheme))
        .navigationTitle(loc.tr("task.title.nav"))
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onDisappear { vm.onDisappear() }  // ✅ INSTANT PREVIEW : Génère PNG avant de quitter
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // âœ¨ Close button avec gradient
                Button { selectionID = nil } label: {
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
                .help(loc.tr("common.close"))
            }
        }

        .onChange(of: vm.status) { _, _ in vm.commitLight() }
        .onChange(of: vm.hasDueDate) { _, _ in vm.commitLight() }
        .onChange(of: vm.dueDate) { _, _ in vm.commitLight() }
        .onChange(of: vm.noteText) { _, _ in vm.commitLight() }
        .onChange(of: vm.color) { _, _ in vm.commitLight() }

        .alert(loc.tr("task.hand.title.clear.confirmTitle"), isPresented: $confirmClearTitle) {
            Button(loc.tr("common.cancel"), role: .cancel) {}
            Button(loc.tr("common.delete"), role: .destructive) { vm.clearTitleDrawing() }
        } message: {
            Text(loc.tr("task.hand.title.clear.confirmMsg"))
        }

        .alert(loc.tr("task.hand.body.clear.confirmTitle"), isPresented: $confirmClearBody) {
            Button(loc.tr("common.cancel"), role: .cancel) {}
            Button(loc.tr("common.delete"), role: .destructive) { vm.clearBodyDrawing() }
        } message: {
            Text(loc.tr("task.hand.body.clear.confirmMsg"))
        }
    }

    // MARK: - Header Card (REDESIGNED)

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            // âœ¨ Title avec gradient background
            TextField(loc.tr("task.typedTitle.placeholder"), text: typedTitleBinding, axis: .vertical)
                .font(.title2.weight(.bold))
                .lineLimit(1...2)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.cardBackground(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(LinearGradient.primaryGradient, lineWidth: 2)
                )

            // âœ¨ Status selector avec boutons gradient (iPad friendly)
            VStack(alignment: .leading, spacing: 12) {
                Text(loc.tr("task.status.label"))
                    .font(.headline)
                    .foregroundStyle(Color.primaryText(colorScheme))
                
                HStack(spacing: 12) {
                    // Todo button
                    StatusButton(
                        status: .todo,
                        isSelected: vm.status == .todo,
                        action: { vm.status = .todo }
                    )
                    
                    // Doing button
                    StatusButton(
                        status: .doing,
                        isSelected: vm.status == .doing,
                        action: { vm.status = .doing }
                    )
                    
                    // Done button
                    StatusButton(
                        status: .done,
                        isSelected: vm.status == .done,
                        action: { vm.status = .done }
                    )
                }
            }

            // âœ¨ Color selector avec gradients
            colorDotsRow

            // âœ¨ Due date avec gradient toggle
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $vm.hasDueDate) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(vm.hasDueDate ? LinearGradient.primaryGradient : LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing))
                                .frame(width: 32, height: 32)
                                .shadow(color: vm.hasDueDate ? Color.primaryStart.opacity(0.3) : .clear, radius: 6, y: 2)
                            
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        Text(loc.tr("task.due.toggle"))
                            .font(.headline)
                            .foregroundStyle(Color.primaryText(colorScheme))
                    }
                }
                .toggleStyle(.button)
                
                if vm.hasDueDate {
                    DatePicker(loc.tr("task.due.picker"), selection: $vm.dueDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.cardBackground(colorScheme))
                        )
                }
            }

            Divider().opacity(0.3)

            // âœ¨ Note section
            VStack(alignment: .leading, spacing: 12) {
                Text(loc.tr("task.note.label"))
                    .font(.headline)
                    .foregroundStyle(Color.primaryText(colorScheme))

                TextEditor(text: $vm.noteText)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.cardBackground(colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primaryText(colorScheme).opacity(0.1), lineWidth: 1)
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.secondaryBackground(colorScheme))
                .shadow(
                    color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.08),
                    radius: 16,
                    y: 8
                )
        )
    }

    // âœ¨ Status icons avec gradients
    private func statusIcon(for status: TaskStatus) -> some View {
        ZStack {
            Circle()
                .fill(statusGradient(for: status))
                .frame(width: 20, height: 20)
            
            Image(systemName: statusIconName(for: status))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    
    private func statusGradient(for status: TaskStatus) -> LinearGradient {
        switch status {
        case .todo: return .todoGradient
        case .doing: return .doingGradient
        case .done: return .doneGradient
        }
    }
    
    private func statusIconName(for status: TaskStatus) -> String {
        switch status {
        case .todo: return "circle"
        case .doing: return "bolt.fill"
        case .done: return "checkmark"
        }
    }

    // âœ¨ Color dots row redesignÃ©
    private var colorDotsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(loc.tr("task.color.label"))
                .font(.headline)
                .foregroundStyle(Color.primaryText(colorScheme))

            HStack(spacing: 16) {
                // None
                ColorDotButton(
                    color: .none,
                    selected: vm.color == .none,
                    gradient: LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing)
                ) { vm.color = .none }

                // Orange
                ColorDotButton(
                    color: .orange,
                    selected: vm.color == .orange,
                    gradient: LinearGradient(colors: [Color.orange, Color.orange.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                ) { vm.color = .orange }

                // Red
                ColorDotButton(
                    color: .red,
                    selected: vm.color == .red,
                    gradient: .urgentGradient
                ) { vm.color = .red }
            }
        }
    }

    // MARK: - Handwriting Cards (REDESIGNED)

    private var titleHandwritingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // âœ¨ Header avec gradient icon - âœ… LABELS RÃ‰DUITS
            HStack(spacing: 10) {  // âœ… RÃ©duit 12 â†’ 10
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)  // âœ… RÃ©duit 10 â†’ 8
                        .fill(LinearGradient.primaryGradient)
                        .frame(width: 32, height: 32)  // âœ… RÃ©duit 40 â†’ 32
                        .shadow(color: Color.primaryStart.opacity(0.3), radius: 4, y: 2)  // âœ… RÃ©duit radius
                    
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 14, weight: .bold))  // âœ… RÃ©duit 18 â†’ 14
                        .foregroundStyle(.white)
                }
                
                Text(loc.tr("task.hand.title.label"))
                    .font(.subheadline.weight(.semibold))  // âœ… RÃ©duit headline â†’ subheadline
                    .foregroundStyle(Color.primaryText(colorScheme))
                
                Spacer()

                Button { confirmClearTitle = true } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help(loc.tr("common.delete"))

                Button { vm.confirmHandwrittenTitle() } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.doneGradient)
                            .frame(width: 32, height: 32)
                            .shadow(color: Color.doneStart.opacity(0.3), radius: 6, y: 2)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .help(loc.tr("common.validate"))
                .disabled(vm.recognizedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // Canvas
            Group {
                if canEditHandwriting {
                    PencilCanvas(drawingData: $vm.titleDrawingData, onEndStroke: {
                        vm.titleStrokeEnded()
                    })
                    .frame(height: 140)
                } else {
                    titlePreviewView
                        .frame(height: 140)
                }
            }
            .background(Color.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LinearGradient.primaryGradient, lineWidth: 2)
            )

            Text(recognizedLine)
                .font(.footnote)
                .foregroundStyle(Color.secondaryText(colorScheme))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.secondaryBackground(colorScheme))
                .shadow(
                    color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.08),
                    radius: 16,
                    y: 8
                )
        )
    }

    private var recognizedLine: String {
        if vm.recognizedTitle.isEmpty {
            return loc.tr("task.hand.recognized.empty")
        } else {
            return "\(loc.tr("task.hand.recognized.prefix")) \(vm.recognizedTitle)"
        }
    }

    @ViewBuilder
    private var titlePreviewView: some View {
        #if os(macOS)
        if let png = task.titleDrawingPreviewPNG,
           let img = NSImage(data: png) {
            Image(nsImage: img)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .padding(10)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "pencil.tip")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.secondary)
                Text(loc.tr("task.hand.recognized.empty"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        #else
        EmptyView()
        #endif
    }

    private var bodyHandwritingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // âœ¨ Header avec gradient icon - âœ… LABELS RÃ‰DUITS
            HStack(spacing: 10) {  // âœ… RÃ©duit 12 â†’ 10
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)  // âœ… RÃ©duit 10 â†’ 8
                        .fill(LinearGradient.doingGradient)
                        .frame(width: 32, height: 32)  // âœ… RÃ©duit 40 â†’ 32
                        .shadow(color: Color.doingStart.opacity(0.3), radius: 4, y: 2)  // âœ… RÃ©duit radius
                    
                    Image(systemName: "pencil.tip") //note.text
                        .font(.system(size: 14, weight: .bold))  // âœ… RÃ©duit 18 â†’ 14
                        .foregroundStyle(.white)
                }
                
                Text(loc.tr("task.hand.body.label"))
                    .font(.subheadline.weight(.semibold))  // âœ… RÃ©duit headline â†’ subheadline
                    .foregroundStyle(Color.primaryText(colorScheme))
                
                Spacer()

                Button { confirmClearBody = true } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help(loc.tr("common.delete"))
            }

            // Canvas
            Group {
                if canEditHandwriting {
                    PencilCanvas(drawingData: $vm.bodyDrawingData, onEndStroke: {
                        vm.bodyStrokeEnded()
                    })
                    .frame(height: 520)
                } else {
                    bodyPreviewView
                        .frame(height: 520)
                }
            }
            .background(Color.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LinearGradient.doingGradient, lineWidth: 2)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.secondaryBackground(colorScheme))
                .shadow(
                    color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.08),
                    radius: 16,
                    y: 8
                )
        )
    }

    @ViewBuilder
    private var bodyPreviewView: some View {
        #if os(macOS)
        if let png = task.bodyDrawingPreviewPNG,
           let img = NSImage(data: png) {
            Image(nsImage: img)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .padding(10)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "pencil.tip")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.secondary)
                Text("â€”")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        #else
        EmptyView()
        #endif
    }
}

// MARK: - Status Button (REDESIGNED - iPad friendly)

private struct StatusButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var loc: LocalizationManager
    
    let status: TaskStatus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: iconLabelSpacing) {
                // Icon gradient
                ZStack {
                    Circle()
                        .fill(statusGradient)
                        .frame(width: iconSize, height: iconSize)
                        .shadow(
                            color: isSelected ? statusGradient.shadowColor : .clear,
                            radius: isSelected ? shadowRadius : 0,
                            y: isSelected ? shadowY : 0
                        )
                    
                    Image(systemName: statusIcon)
                        .font(.system(size: iconFontSize, weight: .bold))
                        .foregroundStyle(.white)
                    
                    // Selection ring
                    if isSelected {
                        Circle()
                            .stroke(statusGradient, lineWidth: ringLineWidth)
                            .frame(width: ringSize, height: ringSize)
                    }
                }
                
                // Label
                Text(statusLabel)
                    .font(.system(size: labelFontSize, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.primaryText(colorScheme) : Color.secondaryText(colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isSelected ? Color.secondaryBackground(colorScheme) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? statusGradient : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing),
                        lineWidth: borderLineWidth
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - macOS Compact Sizing
    
    #if os(macOS)
    private let iconSize: CGFloat = 36  // au lieu de 50
    private let iconFontSize: CGFloat = 16  // au lieu de 22
    private let ringSize: CGFloat = 44  // au lieu de 60
    private let ringLineWidth: CGFloat = 2  // au lieu de 3
    private let iconLabelSpacing: CGFloat = 6  // au lieu de 10
    private let labelFontSize: CGFloat = 12  // au lieu de 14
    private let verticalPadding: CGFloat = 12  // au lieu de 16
    private let cornerRadius: CGFloat = 12  // au lieu de 16
    private let borderLineWidth: CGFloat = 1.5  // au lieu de 2
    private let shadowRadius: CGFloat = 8  // au lieu de 12
    private let shadowY: CGFloat = 4  // au lieu de 6
    #else
    // âœ… iOS - DIVISE PAR 2 + LABELS +20%
    private let iconSize: CGFloat = 25  // âœ… 50 â†’ 25
    private let iconFontSize: CGFloat = 11  // âœ… 22 â†’ 11
    private let ringSize: CGFloat = 30  // âœ… 60 â†’ 30
    private let ringLineWidth: CGFloat = 1.5  // âœ… 3 â†’ 1.5
    private let iconLabelSpacing: CGFloat = 5  // âœ… 10 â†’ 5
    private let labelFontSize: CGFloat = 8.5  // âœ… 7 â†’ 8.5 (+20%)
    private let verticalPadding: CGFloat = 8  // âœ… 16 â†’ 8
    private let cornerRadius: CGFloat = 8  // âœ… 16 â†’ 8
    private let borderLineWidth: CGFloat = 1  // âœ… 2 â†’ 1
    private let shadowRadius: CGFloat = 6  // âœ… 12 â†’ 6
    private let shadowY: CGFloat = 3  // âœ… 6 â†’ 3
    #endif
    
    private var statusGradient: LinearGradient {
        switch status {
        case .todo: return .todoGradient
        case .doing: return .doingGradient
        case .done: return .doneGradient
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .todo: return "circle"
        case .doing: return "bolt.fill"
        case .done: return "checkmark.circle.fill"
        }
    }
    
    private var statusLabel: String {
        switch status {
        case .todo: return loc.tr("status.todo")
        case .doing: return loc.tr("status.doing")
        case .done: return loc.tr("status.done")
        }
    }
}

// MARK: - Color Dot Button (REDESIGNED)

private struct ColorDotButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var loc: LocalizationManager

    let color: TaskColor
    let selected: Bool
    let gradient: LinearGradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: 22, height: 22)  // âœ… RÃ©duit de 50% (44 â†’ 22)
                    .shadow(
                        color: selected ? gradient.shadowColor : .clear,
                        radius: 4,  // âœ… RÃ©duit proportionnellement
                        y: 2
                    )
                
                if selected {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)  // âœ… RÃ©duit (3 â†’ 2)
                        .frame(width: 18, height: 18)  // âœ… RÃ©duit de 50% (36 â†’ 18)
                }
                
                if color == .none {
                    Image(systemName: "slash.circle")
                        .font(.system(size: 10, weight: .bold))  // âœ… RÃ©duit de 50% (20 â†’ 10)
                        .foregroundStyle(.white)
                }
            }
            .scaleEffect(selected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
        }
        .buttonStyle(.plain)
        .help(colorHelp)
    }

    private var colorHelp: String {
        switch color {
        case .none: return loc.tr("task.color.none")
        case .orange: return loc.tr("task.color.orange")
        case .red: return loc.tr("task.color.red")
        }
    }
}
