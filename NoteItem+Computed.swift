import Foundation

extension NoteItem {
    /// Règle: si typedTitle non vide => on prend typedTitle
    /// sinon on prend recognizedTitle (sinon "—")
    var effectiveTitle: String {
        let typed = (typedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }

        let rec = (recognizedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !rec.isEmpty { return rec }

        return "—"
    }

    var isTypedTitleEmpty: Bool {
        (typedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
