import SwiftUI
import CoreData
#if os(macOS)
import AppKit
#endif

/// ✨ NoteRow avec stroke de sélection
struct NoteRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var note: NoteItem
    
    // ✅ Détecte si la row est sélectionnée
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleView
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(dateLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
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

    @ViewBuilder
    private var titleView: some View {
        if shouldShowHandwrittenTitle {
            #if os(iOS)
            if let data = note.titleDrawingData, !data.isEmpty {
                HandwrittenTitleRowView(drawingData: data, height: 30)
                    .padding(.vertical, 2)
            }
            #elseif os(macOS)
            if let png = note.titleDrawingPreviewPNG,
               let nsImage = NSImage(data: png) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 32)
                    .padding(.vertical, 2)
            }
            #endif
        } else {
            Text(effectiveTitle.isEmpty ? "—" : effectiveTitle)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    private var shouldShowHandwrittenTitle: Bool {
        let typed = (note.typedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard typed.isEmpty else { return false }

        #if os(iOS)
        return (note.titleDrawingData?.isEmpty == false)
        #elseif os(macOS)
        return (note.titleDrawingPreviewPNG?.isEmpty == false)
        #else
        return false
        #endif
    }

    private var effectiveTitle: String {
        let typed = (note.typedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }

        let recognized = (note.recognizedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !recognized.isEmpty { return recognized }

        return ""
    }

    private var dateLine: String {
        let d = note.createdAt ?? note.updatedAt ?? Date()
        return d.compactRelativeFormat()
    }
}
