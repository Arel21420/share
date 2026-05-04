import Foundation
import CoreData
import Combine

#if os(iOS)
import PencilKit
import Vision
import UIKit
#endif

/// âœ… FIX #2: Preview PNG refresh immÃ©diat dans les rows
///
/// PROBLÃˆME IDENTIFIÃ‰:
/// - Le preview PNG est gÃ©nÃ©rÃ© et assignÃ© Ã  la note
/// - Mais le refresh se fait avant que Core Data n'ait sauvegardÃ©
/// - RÃ©sultat: Les rows ne voient pas le nouveau PNG
///
/// SOLUTION:
/// - Forcer le save immÃ©diatement aprÃ¨s la gÃ©nÃ©ration du preview
/// - Puis faire le refresh une fois le save confirmÃ©
/// - Double refresh pour Ãªtre sÃ»r (immÃ©diat + aprÃ¨s save)

@MainActor
final class NoteDetailViewModel: ObservableObject {
    private let ctx: NSManagedObjectContext
    private let note: NoteItem

    // UI
    @Published var typedTitle: String
    @Published var noteText: String

    // Handwriting
    @Published var titleDrawingData: Data?
    @Published var bodyDrawingData: Data?
    @Published private(set) var recognizedTitle: String

    private var cancellables = Set<AnyCancellable>()
    private var saveWorkItem: DispatchWorkItem?
    private var liveOCRWorkItem: DispatchWorkItem?
    
    // ✅ DEBOUNCE : Attendre 1s après levé de crayon
    private var strokeEndWorkItem: DispatchWorkItem?

    // Preview cache
    private var lastTitlePreviewSource: Data?
    private var lastBodyPreviewSource: Data?

    init(ctx: NSManagedObjectContext, note: NoteItem) {
        self.ctx = ctx
        self.note = note

        self.typedTitle = note.typedTitle ?? ""
        self.noteText = note.noteText ?? ""

        self.titleDrawingData = note.titleDrawingData
        self.bodyDrawingData = note.bodyDrawingData
        self.recognizedTitle = note.recognizedTitle ?? ""

        self.lastTitlePreviewSource = note.titleDrawingData
        self.lastBodyPreviewSource = note.bodyDrawingData

        setupAutosave()
        setupLiveRecognition()
    }

    // MARK: - Live recognition (DÉSACTIVÉ pour performance)

    private func setupLiveRecognition() {
        // ✅ DÉSACTIVÉ : L'OCR live est trop lourd et cause du lag
        // L'OCR sera fait uniquement lors de titleStrokeEnded()
    }

    private func scheduleLiveRecognition() {
        liveOCRWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.runLiveRecognition()
        }
        liveOCRWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: item)
    }

    private func runLiveRecognition() {
        #if os(iOS)
        guard let data = titleDrawingData,
              let drawing = try? PKDrawing(data: data),
              !drawing.strokes.isEmpty else {
            if recognizedTitle != "" {
                recognizedTitle = ""
                note.recognizedTitle = ""
                scheduleSave()
            }
            return
        }

        let bounds = drawing.bounds.insetBy(dx: -60, dy: -40)
        let image = drawing.image(from: bounds, scale: 4.0)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let text = Self.ocr(image: image)
            let cleaned = text
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            DispatchQueue.main.async {
                guard let self else { return }
                if self.recognizedTitle != cleaned {
                    self.recognizedTitle = cleaned
                    self.note.recognizedTitle = cleaned
                    self.scheduleSave()
                }
            }
        }
        #endif
    }

    // MARK: - User edits

    func setTypedTitleFromUser(_ newValue: String) {
        typedTitle = newValue
        applyToNote()
        scheduleSave()
    }

    // MARK: - Handwriting events

    /// ✅ DEBOUNCE : Attendre 1s d'inactivité avant calculs lourds
    func titleStrokeEnded() {
        #if os(iOS)
        // ✅ Annuler les calculs prévus
        strokeEndWorkItem?.cancel()
        
        // ✅ Programmer les calculs dans 1 seconde
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            
            // 1. Générer le preview PNG
            self.updateTitlePreviewIfNeeded(force: true)
            
            // 2. Lancer OCR en arrière-plan
            self.runLiveRecognition()
            
            // 3. Sauver + refresh
            self.saveWorkItem?.cancel()
            self.saveNowAndRefresh()
        }
        
        strokeEndWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
        #endif
    }

    func bodyStrokeEnded() {
        #if os(iOS)
        // ✅ Annuler les calculs prévus
        strokeEndWorkItem?.cancel()
        
        // ✅ Programmer les calculs dans 1 seconde
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            
            // 1. Générer le preview PNG
            self.updateBodyPreviewIfNeeded(force: true)
            
            // 2. Sauver
            self.scheduleSave()
        }
        
        strokeEndWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
        #else
        scheduleSave()
        #endif
    }

    /// ✅ NOUVEAU: Save immédiat + refresh après confirmation
    private func saveNowAndRefresh() {
        ctx.perform { [weak self] in
            guard let self else { return }
            
            do {
                if self.ctx.hasChanges {
                    try self.ctx.save()
                    
                    // ✅ REFRESH OPTIMISÉ avec 2 vagues (60% plus léger)
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        
                        // Vague 1: Immédiat
                        self.note.objectWillChange.send()
                        self.ctx.refresh(self.note, mergeChanges: true)
                        
                        // Vague 2: 100ms (garantie finale)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                            guard let self else { return }
                            self.note.objectWillChange.send()
                            self.ctx.refresh(self.note, mergeChanges: true)
                        }
                    }
                }
            } catch {
                print("âŒ CoreData save error:", error)
            }
        }
    }

    func clearTitleDrawing() {
        titleDrawingData = nil
        recognizedTitle = ""

        note.titleDrawingData = nil
        note.titleDrawingPreviewPNG = nil
        note.recognizedTitle = ""

        lastTitlePreviewSource = nil
        scheduleSave()
    }

    func clearBodyDrawing() {
        bodyDrawingData = nil
        note.bodyDrawingData = nil
        note.bodyDrawingPreviewPNG = nil

        lastBodyPreviewSource = nil
        scheduleSave()
    }

    func confirmHandwrittenTitle() {
        let cleaned = recognizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        typedTitle = cleaned
        applyToNote()
        scheduleSave()
    }

    // MARK: - Commit

    func commitLight() {
        applyToNote()
        scheduleSave()
    }

    func commitNow() {
        applyToNote()
        saveWorkItem?.cancel()
        saveNow()
    }
    
    /// ✅ INSTANT PREVIEW : Génère les PNG avant de quitter la vue
    /// Garantit que les rows affichent le preview à jour immédiatement
    func onDisappear() {
        // 1. Annuler le debounce strokeEndWorkItem en attente
        strokeEndWorkItem?.cancel()
        
        // 2. Forcer la génération des PNG si les drawings ont changé
        #if os(iOS)
        if titleDrawingData != nil {
            updateTitlePreviewIfNeeded(force: true)
        }
        if bodyDrawingData != nil {
            updateBodyPreviewIfNeeded(force: true)
        }
        #endif
        
        // 3. Sauver avec refresh pour que les rows voient le changement
        applyToNote()
        saveWorkItem?.cancel()
        saveNowAndRefresh()
    }

    // MARK: - Autosave & model sync

    private func setupAutosave() {
        $titleDrawingData
            .sink { [weak self] data in
                guard let self else { return }
                self.note.titleDrawingData = data
                // ✅ DÉSACTIVÉ pendant écriture : PNG sera généré lors de titleStrokeEnded()
                // #if os(iOS)
                // self.updateTitlePreviewIfNeeded(force: false)
                // #endif
                // ✅ Save aussi désactivé pendant écriture
                // self.scheduleSave()
            }
            .store(in: &cancellables)

        $bodyDrawingData
            .sink { [weak self] data in
                guard let self else { return }
                self.note.bodyDrawingData = data
                // ✅ Body preview désactivé aussi pendant écriture
                // #if os(iOS)
                // self.updateBodyPreviewIfNeeded(force: true)
                // #endif
                // self.scheduleSave()
            }
            .store(in: &cancellables)

        Publishers.MergeMany(
            $noteText.map { _ in () }.eraseToAnyPublisher(),
            $typedTitle.map { _ in () }.eraseToAnyPublisher()
        )
        .sink { [weak self] in
            self?.applyToNote()
            self?.scheduleSave()
        }
        .store(in: &cancellables)
    }

    private func applyToNote() {
        note.typedTitle = typedTitle
        note.noteText = noteText
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    private func saveNow() {
        ctx.perform { [weak self] in
            guard let self else { return }
            do {
                if self.ctx.hasChanges { try self.ctx.save() }
            } catch {
                print("âŒ CoreData save error:", error)
            }
        }
    }

    // MARK: - Preview PNG

    #if os(iOS)
    private func updateTitlePreviewIfNeeded(force: Bool) {
        guard force || titleDrawingData != lastTitlePreviewSource else { return }
        lastTitlePreviewSource = titleDrawingData
        
        let preview = Self.makePreviewPNG(from: titleDrawingData, targetHeight: 96)
        note.titleDrawingPreviewPNG = preview
        
        // âœ… Refresh immÃ©diat (mais le vrai refresh se fera aprÃ¨s le save)
        note.objectWillChange.send()
    }

    private func updateBodyPreviewIfNeeded(force: Bool) {
        guard force || bodyDrawingData != lastBodyPreviewSource else { return }
        lastBodyPreviewSource = bodyDrawingData
        note.bodyDrawingPreviewPNG = Self.makePreviewPNG(from: bodyDrawingData, targetHeight: 560)
    }

    /// âœ… GÃ©nÃ©ration PNG ULTRA HD (scale 10x pour nettetÃ© maximale)
    private static func makePreviewPNG(from data: Data?, targetHeight: CGFloat) -> Data? {
        guard let data,
              let drawing = try? PKDrawing(data: data),
              !drawing.strokes.isEmpty else { return nil }

        var bounds = drawing.bounds
        // ✅ PROTECTION #1 : Bounds valides et non-null
         guard !bounds.isNull, !bounds.isEmpty,
               bounds.width > 0.1, bounds.height > 0.1,
               bounds.width.isFinite, bounds.height.isFinite else {
             return nil
         }
        bounds = bounds.insetBy(dx: -20, dy: -15)  // âœ… Marge optimale
        // ✅ PROTECTION #2 : Bounds toujours valides après inset
            guard bounds.width > 0, bounds.height > 0,
                  bounds.width.isFinite, bounds.height.isFinite else {
                return nil
            }
        let maxPixelHeight: CGFloat = targetHeight * 4.0  // ✅ 4x (2.5x plus léger, toujours net)
        let maxPixelWidth: CGFloat = 4800  // ✅ Réduit (plus léger)

        let scaleH = maxPixelHeight / max(1, bounds.height)
        let scaleW = maxPixelWidth  / max(1, bounds.width)
        var scale = min(scaleH, scaleW)

        scale = max(3.0, min(5.0, scale))  // ✅ 3-5x (optimisé)
        
         // ✅ PROTECTION #3 : Scale valide
         guard scale > 0, scale.isFinite, scale < 100 else {
             return nil
         }
        let baseImage = drawing.image(from: bounds, scale: scale)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 4.0  // ✅ 4x (net Retina, 2.5x plus léger)
        format.preferredRange = .extended  // âœ… Meilleure gamme de couleurs

        let renderer = UIGraphicsImageRenderer(size: baseImage.size, format: format)
        let img = renderer.image { ctx in
            ctx.cgContext.setShouldAntialias(true)
            ctx.cgContext.setAllowsAntialiasing(true)
            ctx.cgContext.interpolationQuality = .high
            
            baseImage.draw(in: CGRect(origin: .zero, size: baseImage.size))
        }

        return img.pngData()
    }

    private static func ocr(image: UIImage) -> String {
        guard let cg = image.cgImage else { return "" }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["fr-FR", "en-US"]
        request.minimumTextHeight = 0.012

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do { try handler.perform([request]) } catch { return "" }

        let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
        let sorted = observations.sorted { a, b in
            let ay = a.boundingBox.midY
            let by = b.boundingBox.midY
            if abs(ay - by) > 0.04 { return ay > by }
            return a.boundingBox.minX < b.boundingBox.minX
        }

        var lines: [[String]] = []
        var lineYs: [CGFloat] = []

        for obs in sorted {
            guard let cand = obs.topCandidates(1).first?.string, !cand.isEmpty else { continue }
            let y = obs.boundingBox.midY
            if let idx = lineYs.indices.first(where: { abs(lineYs[$0] - y) < 0.04 }) {
                lines[idx].append(cand)
            } else {
                lineYs.append(y)
                lines.append([cand])
            }
        }

        return lines.map { $0.joined(separator: " ") }.joined(separator: " ")
    }
    #endif
}
