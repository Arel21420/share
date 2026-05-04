import SwiftUI

#if os(iOS)
import PencilKit
import UIKit

/// ✅ VERSION SAFE : Protection contre dimensions invalides
/// Corrige l'erreur "Invalid frame dimension (negative or non-finite)"
struct HandwrittenTitleRowView: View {
    let drawingData: Data?
    var height: CGFloat = 28

    @State private var rendered: UIImage? = nil
    @State private var lastHash: Int = 0

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(height, 1)

            Group {
                if let img = rendered {
                    Image(uiImage: img)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: w, height: h, alignment: .leading)
                } else {
                    // Fallback (quand rien à afficher)
                    Color.clear
                        .frame(width: w, height: h)
                }
            }
            .onAppear {
                renderIfNeeded(targetWidth: w, targetHeight: h)
            }
            .onChange(of: drawingData) { _ in
                renderIfNeeded(targetWidth: w, targetHeight: h)
            }
            .onChange(of: geo.size.width) { _ in
                renderIfNeeded(targetWidth: w, targetHeight: h)
            }
        }
        .frame(height: height)
        .clipped()
        .accessibilityLabel("Handwritten title")
    }

    private func renderIfNeeded(targetWidth: CGFloat, targetHeight: CGFloat) {
        guard let data = drawingData,
              let drawing = try? PKDrawing(data: data),
              !drawing.strokes.isEmpty else {
            rendered = nil
            lastHash = 0
            return
        }

        // Hash simple : si rien n'a changé, ne re-render pas
        let h = data.hashValue ^ Int(targetWidth.rounded()) ^ Int(targetHeight.rounded())
        if h == lastHash { return }
        lastHash = h

        // Render en image "fit"
        let img = Self.renderDrawingImage(
            drawing: drawing,
            targetWidth: targetWidth,
            targetHeight: targetHeight
        )
        rendered = img
    }

    private static func renderDrawingImage(drawing: PKDrawing, targetWidth: CGFloat, targetHeight: CGFloat) -> UIImage? {
        // ✅ PROTECTION #1 : Vérifier que targetWidth/Height sont valides
        guard targetWidth > 0, targetHeight > 0,
              targetWidth.isFinite, targetHeight.isFinite else {
            return nil
        }
        
        let bounds = drawing.bounds
        
        // ✅ PROTECTION #2 : Vérifier que bounds sont valides
        guard bounds.width > 0.1, bounds.height > 0.1,
              bounds.width.isFinite, bounds.height.isFinite else {
            return nil
        }

        // Un peu de padding pour éviter de couper les traits aux bords
        let padded = bounds.insetBy(dx: -12, dy: -8)
        
        // ✅ PROTECTION #3 : Vérifier que padded est toujours valide
        guard padded.width > 0, padded.height > 0,
              padded.width.isFinite, padded.height.isFinite else {
            return nil
        }

        // Scale pour "fit" dans la zone (aspectFit)
        let sx = targetWidth / padded.width
        let sy = targetHeight / padded.height
        let fit = min(sx, sy)
        
        // ✅ PROTECTION #4 : Vérifier que fit est valide
        guard fit > 0, fit.isFinite else {
            return nil
        }

        // La fonction image(from:scale:) attend un scale "pixels per point".
        // On combine le fit avec le scale écran pour garder de la netteté.
        let scale = max(1.0, UIScreen.main.scale * fit)
        
        // ✅ PROTECTION #5 : Vérifier que scale est raisonnable
        guard scale > 0, scale < 100, scale.isFinite else {
            return nil
        }

        // Render
        return drawing.image(from: padded, scale: scale)
    }
}

#else

// macOS / autres : PencilKit indispo en natif => pas d'affichage "dessin" ici
struct HandwrittenTitleRowView: View {
    let drawingData: Data?
    var height: CGFloat = 28
    var body: some View { EmptyView() }
}

#endif
