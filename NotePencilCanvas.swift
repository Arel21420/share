import SwiftUI

#if os(iOS)
import PencilKit
import UIKit

/// Canvas dÃ©diÃ© aux NOTES.
/// - Pendant le trait: update classique (async pour Ã©viter warnings SwiftUI)
/// - Fin de trait: FLUSH synchrone immÃ©diat + callback
struct NotePencilCanvas: UIViewRepresentable {
    @Binding var drawingData: Data?
    var onEndStroke: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(drawingData: $drawingData, onEndStroke: onEndStroke)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let v = PKCanvasView()
        v.backgroundColor = .clear
        v.isOpaque = false
        v.drawingPolicy = .pencilOnly
        v.delegate = context.coordinator

        // PKCanvasView est un UIScrollView â†’ dans ScrollView SwiftUI, on neutralise
        v.isScrollEnabled = false
        v.bounces = false
        v.alwaysBounceVertical = false
        v.alwaysBounceHorizontal = false
        v.minimumZoomScale = 1.0
        v.maximumZoomScale = 1.0

        if let data = drawingData,
           let drawing = try? PKDrawing(data: data) {
            v.drawing = drawing
        } else {
            v.drawing = PKDrawing()
        }

        context.coordinator.attachToolPicker(to: v)
        context.coordinator.attachEndStrokeListener(to: v)

        return v
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if drawingData == nil {
            if !uiView.drawing.strokes.isEmpty {
                uiView.drawing = PKDrawing()
            }
            return
        }
        // On ne rÃ©injecte pas uiView.drawing en boucle.
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawingData: Data?
        var onEndStroke: (() -> Void)?

        private weak var canvasView: PKCanvasView?
        private weak var toolPicker: PKToolPicker?
        private var didAttachGestureListener = false
        private var lastPublishedData: Data?

        init(drawingData: Binding<Data?>, onEndStroke: (() -> Void)?) {
            _drawingData = drawingData
            self.onEndStroke = onEndStroke
        }
        
        // ✅ FIX REGRESSION : Flush automatique quand le Coordinator est détruit
        // Garantit que le dernier trait est sauvé même si l'utilisateur change de vue rapidement
        deinit {
            if let canvas = canvasView {
                flushNow(canvas)
            }
        }

        func attachToolPicker(to canvas: PKCanvasView) {
            self.canvasView = canvas

            DispatchQueue.main.async { [weak self] in
                guard let self, let canvas = self.canvasView else { return }
                guard let window = canvas.window ?? UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first(where: { $0.isKeyWindow }) else { return }

                let picker = PKToolPicker.shared(for: window)
                self.toolPicker = picker
                picker?.addObserver(canvas)
                picker?.setVisible(true, forFirstResponder: canvas)
                canvas.becomeFirstResponder()
            }
        }

        func attachEndStrokeListener(to canvas: PKCanvasView) {
            guard !didAttachGestureListener else { return }
            didAttachGestureListener = true
            self.canvasView = canvas
            canvas.drawingGestureRecognizer.addTarget(self, action: #selector(handleDrawingGesture(_:)))
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // ✅ NE RIEN FAIRE PENDANT L'ÉCRITURE !
            // On ne publie QU'À LA FIN du trait (dans flushNow)
        }

        // Fin dâ€™utilisation outil (pas fiable), mais on garde
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            flushNow(canvasView)
        }

        // âœ… Fin de trait fiable
        @objc private func handleDrawingGesture(_ gr: UIGestureRecognizer) {
            guard let canvas = canvasView else { return }
            switch gr.state {
            case .ended, .cancelled, .failed:
                flushNow(canvas)
            default:
                break
            }
        }

        private func flushNow(_ canvasView: PKCanvasView) {
            // âœ… FLUSH synchro immÃ©diat = corrige â€œdernier trait perduâ€
            let data = canvasView.drawing.dataRepresentation()
            if lastPublishedData != data {
                lastPublishedData = data
                drawingData = data
            }
            onEndStroke?()
        }
    }
}

#else

struct NotePencilCanvas: View {
    @Binding var drawingData: Data?
    var onEndStroke: (() -> Void)? = nil
    var body: some View { EmptyView() }
}
#endif
