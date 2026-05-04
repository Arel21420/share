import SwiftUI
import CoreData

/// ✨ TaskRow avec stroke de sélection
struct TaskRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var task: TaskItem
    
    // ✅ Détecte si la row est sélectionnée
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            
            titleView
                .lineLimit(2)
            
            Spacer()
            
            if let dueDate = task.dueDate {
                dueDateBadge(dueDate)
            }
            
            if task.color != .none, let c = task.color.uiColor {
                Circle()
                    .fill(Color(c))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        // ✅ NOUVEAU: Stroke au lieu de background
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(selectionStrokeStyle, lineWidth: 2)
        )
    }
    
    // ✅ Style de stroke unifié (évite erreur de type)
    private var selectionStrokeStyle: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(selectionStrokeGradient)
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }
    
    // ✅ Stroke gradient selon light/dark mode
    private var selectionStrokeGradient: LinearGradient {
        if colorScheme == .dark {
            // Dark mode: Violet-bleu (comme titre manuscrit tâche)
            return LinearGradient.primaryGradient
        } else {
            // Light mode: Jaune-orangé (comme note manuscrit tâche)
            return LinearGradient.doingGradient
        }
    }
    
    private var statusIcon: some View {
        Group {
            switch task.status {
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .doing:
                Image(systemName: "circle.dotted")
                    .foregroundStyle(.orange)
            case .todo:
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.title3)
    }
    
    @ViewBuilder
    private var titleView: some View {
        #if os(iOS)
        if shouldShowHandwrittenTitle, let data = task.titleDrawingData, !data.isEmpty {
            HandwrittenTitleRowView(drawingData: data, height: 28)
        } else {
            Text(task.effectiveTitle.isEmpty ? "—" : task.effectiveTitle)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
        }
        #elseif os(macOS)
        if shouldShowHandwrittenTitle, let png = task.titleDrawingPreviewPNG, let nsImage = NSImage(data: png) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 28)
        } else {
            Text(task.effectiveTitle.isEmpty ? "—" : task.effectiveTitle)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
        }
        #else
        Text(task.effectiveTitle.isEmpty ? "—" : task.effectiveTitle)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
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
    
    private func dueDateBadge(_ date: Date) -> some View {
        Text(date.compactRelativeFormat())
            .font(.caption2)
            .foregroundStyle(task.isOverdue ? .red : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(task.isOverdue ? Color.red.opacity(0.15) : Color.secondary.opacity(0.1))
            )
    }
}
