import Foundation
import Vision
import PencilKit

#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum HandwritingOCR {
    static func recognizeTitle(from drawingData: Data?) async -> String {
        guard
            let drawingData,
            let drawing = try? PKDrawing(data: drawingData)
        else { return "" }

        guard let cgImage = drawingToCGImage(drawing) else { return "" }

        return await recognizeText(in: cgImage)
    }

    private static func recognizeText(in cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let strings = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []

                // Un titre : on concatène proprement, puis on nettoie
                let joined = strings.joined(separator: " ")
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                continuation.resume(returning: joined)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.customWords = [] // tu peux ajouter tes termes métier ici
            request.minimumTextHeight = 0.02

            // Langues possibles: fr-FR, en-US…
            request.recognitionLanguages = ["fr-FR", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }

    private static func drawingToCGImage(_ drawing: PKDrawing) -> CGImage? {
        // On rend une image “plate” du titre manuscrit (zone courte)
        let bounds = drawing.bounds.isNull ? CGRect(x: 0, y: 0, width: 1200, height: 300) : drawing.bounds.insetBy(dx: -20, dy: -20)
        let scale: CGFloat = 2.0

        #if os(iOS)
        let uiImage = drawing.image(from: bounds, scale: scale)
        return uiImage.cgImage
        #else
        let nsImage = drawing.image(from: bounds, scale: scale)
        return nsImage.cgImage
        #endif
    }
}

#if os(macOS)
private extension NSImage {
    var cgImage: CGImage? {
        guard let tiff = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.cgImage
    }
}
#endif
