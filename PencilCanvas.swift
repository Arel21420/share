import SwiftUI

#if os(iOS)
import PencilKit
import UIKit

struct PencilCanvas: UIViewRepresentable {
    @Binding var drawingData: Data?

    /// Appelé quand l'utilisateur "termine" un geste
    var onEndStroke: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(drawingData: $drawingData, onEndStroke: onEndStroke)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let v = PKCanvasView()
        v.backgroundColor = .clear
        v.isOpaque = false

        // ✅ iPad : écriture + gomme Apple Pencil (doigt interdit)
        v.drawingPolicy = .pencilOnly
        v.delegate = context.coordinator

        // ✅ IMPORTANT : PKCanvasView est un UIScrollView
        // Dans un ScrollView SwiftUI, ça peut provoquer des comportements "N-1".
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

        // ✅ Active le ToolPicker (palette) : gomme incluse
        context.coordinator.attachToolPicker(to: v)
        
        // ✅ FIX: Écoute les fins de geste pour flush synchrone
        context.coordinator.attachEndStrokeListener(to: v)

        return v
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // ✅ Clear total (corbeille) si tu mets drawingData à nil
        if drawingData == nil {
            if !uiView.drawing.strokes.isEmpty {
                uiView.drawing = PKDrawing()
            }
            return
        }

        // ✅ On ne ré-injecte pas uiView.drawing ici.
        // Le canvas est la source de vérité visuelle pendant l'écriture.
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawingData: Data?
        var onEndStroke: (() -> Void)?

        private weak var canvasView: PKCanvasView?
        private weak var toolPicker: PKToolPicker?
        private var didAttachGestureListener = false

        // ✅ Throttle minimal : 16ms = 60fps
        private var pendingPublish: DispatchWorkItem?
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

        // ✅ FIX: Écoute la fin de trait (gesture recognizer)
        func attachEndStrokeListener(to canvas: PKCanvasView) {
            guard !didAttachGestureListener else { return }
            didAttachGestureListener = true
            self.canvasView = canvas
            canvas.drawingGestureRecognizer.addTarget(self, action: #selector(handleDrawingGesture(_:)))
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // ✅ NE RIEN FAIRE PENDANT L'ÉCRITURE !
            // Le problème : même publier drawingData cause un re-render SwiftUI qui ralentit
            // Solution : On ne publie QU'À LA FIN du trait (dans flushNow)
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            // ✅ Flush final immédiat (garantit que le dernier trait est persisté)
            flushNow(canvasView)
        }

        // ✅ FIX: Fin de trait fiable (gesture recognizer)
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
            // ✅ FLUSH synchro immédiat = corrige "dernier trait perdu"
            pendingPublish?.cancel()

            let data = canvasView.drawing.dataRepresentation()
            if lastPublishedData != data {
                lastPublishedData = data
                drawingData = data
            }

            // ✅ CRITIQUE: onEndStroke appelé QUE en fin de trait
            // Pas pendant l'écriture pour éviter les refreshes !
            onEndStroke?()
        }
    }
}

#else

// macOS / autres : stub (manuscrit masqué)
struct PencilCanvas: View {
    @Binding var drawingData: Data?
    var onEndStroke: (() -> Void)? = nil
    var body: some View { EmptyView() }
}
#endif
