import Foundation
import CoreData
import Combine

#if os(iOS)
import PencilKit
import Vision
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
#endif

@MainActor
final class TaskDetailViewModel: ObservableObject {
    private let ctx: NSManagedObjectContext
    private let task: TaskItem

    // UI
    @Published var typedTitle: String
    @Published var noteText: String
    @Published var status: TaskStatus
    @Published var hasDueDate: Bool
    @Published var dueDate: Date
    @Published var color: TaskColor

    // Handwriting
    @Published var titleDrawingData: Data?
    @Published var bodyDrawingData: Data?
    @Published private(set) var recognizedTitle: String

    private var cancellables = Set<AnyCancellable>()
    private var saveWorkItem: DispatchWorkItem?

    // Live recognition
    private var liveOCRWorkItem: DispatchWorkItem?
    
    // ✅ DEBOUNCE : Attendre 1s après levé de crayon avant calculs lourds
    private var strokeEndWorkItem: DispatchWorkItem?

    // Preview cache
    private var lastTitlePreviewSource: Data?
    private var lastBodyPreviewSource: Data?

    init(ctx: NSManagedObjectContext, task: TaskItem) {
        self.ctx = ctx
        self.task = task

        self.typedTitle = task.typedTitle ?? ""
        self.noteText = task.noteText ?? ""
        self.status = task.status
        self.hasDueDate = (task.dueDate != nil)
        self.dueDate = task.dueDate ?? Date()
        self.color = task.color

        self.titleDrawingData = task.titleDrawingData
        self.bodyDrawingData = task.bodyDrawingData
        self.recognizedTitle = task.recognizedTitle ?? ""

        self.lastTitlePreviewSource = task.titleDrawingData
        self.lastBodyPreviewSource = task.bodyDrawingData

        setupAutosave()
        setupLiveRecognition()
    }

    // MARK: - Live recognition (DÉSACTIVÉ pour performance)

    private func setupLiveRecognition() {
        // ✅ DÉSACTIVÉ : L'OCR live est trop lourd et cause du lag
        // L'OCR sera fait uniquement lors de titleStrokeEnded()
        // Plus de réactivité pendant l'écriture !
    }

    private func scheduleLiveRecognition() {
        liveOCRWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.runLiveRecognition()
        }
        liveOCRWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)  // ✅ 0.3s au lieu de 1.0s
    }

    private func runLiveRecognition() {
        #if os(iOS)
        guard let data = titleDrawingData,
              let drawing = try? PKDrawing(data: data),
              !drawing.strokes.isEmpty else {
            if recognizedTitle != "" {
                recognizedTitle = ""
                task.recognizedTitle = ""
                scheduleSave()
            }
            return
        }

        let bounds = drawing.bounds.insetBy(dx: -60, dy: -40)
        let image = drawing.image(from: bounds, scale: 4.0)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let text = Self.ocrBestEffort(image: image, accurate: true)
            let cleaned = text
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            DispatchQueue.main.async {
                guard let self else { return }
                if self.recognizedTitle != cleaned {
                    self.recognizedTitle = cleaned
                    self.task.recognizedTitle = cleaned
                    self.scheduleSave()
                }
            }
        }
        #endif
    }

    // MARK: - User edits

    func setTypedTitleFromUser(_ newValue: String) {
        typedTitle = newValue
        applyToTask()
        scheduleSave()
    }

    // MARK: - Handwriting events

    /// ✅ DEBOUNCE : Attendre 1s d'inactivité avant calculs lourds
    func titleStrokeEnded() {
        #if os(iOS)
        // ✅ Annuler les calculs prévus (si nouveau trait dans la seconde)
        strokeEndWorkItem?.cancel()
        
        // ✅ Programmer les calculs lourds dans 1 seconde
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
        
        // ✅ Attendre 1 seconde : si tu écris vite, aucun calcul entre les traits !
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
        #endif
    }

    /// ✅ DEBOUNCE : Body aussi avec 1s d'attente
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

    func clearTitleDrawing() {
        titleDrawingData = nil
        recognizedTitle = ""

        task.titleDrawingData = nil
        task.titleDrawingPreviewPNG = nil
        task.recognizedTitle = ""

        lastTitlePreviewSource = nil
        scheduleSave()
    }

    func clearBodyDrawing() {
        bodyDrawingData = nil
        task.bodyDrawingData = nil
        task.bodyDrawingPreviewPNG = nil

        lastBodyPreviewSource = nil
        scheduleSave()
    }

    func confirmHandwrittenTitle() {
        let cleaned = recognizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        typedTitle = cleaned
        applyToTask()
        scheduleSave()
    }

    // MARK: - Commit

    func commitLight() {
        applyToTask()
        scheduleSave()
    }

    func commitNow() {
        applyToTask()
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
        applyToTask()
        saveWorkItem?.cancel()
        saveNowAndRefresh()
    }

    // MARK: - Autosave

    private func setupAutosave() {
        $titleDrawingData
            .sink { [weak self] data in
                guard let self else { return }
                self.task.titleDrawingData = data
                // ✅ DÉSACTIVÉ pendant écriture : la génération PNG sera faite lors de titleStrokeEnded()
                // Ça évite le lag pendant l'écriture !
                // #if os(iOS)
                // self.updateTitlePreviewIfNeeded(force: false)
                // #endif
                // ✅ Save aussi désactivé pendant écriture (sera fait lors de titleStrokeEnded())
                // self.scheduleSave()
            }
            .store(in: &cancellables)

        $bodyDrawingData
            .sink { [weak self] data in
                guard let self else { return }
                self.task.bodyDrawingData = data
                #if os(iOS)
                // âœ… FIX: Force true pour mettre Ã  jour le preview Ã  chaque changement
                self.updateBodyPreviewIfNeeded(force: true)
                #endif
                self.scheduleSave()
            }
            .store(in: &cancellables)

        Publishers.MergeMany(
            $noteText.map { _ in () }.eraseToAnyPublisher(),
            $status.map { _ in () }.eraseToAnyPublisher(),
            $hasDueDate.map { _ in () }.eraseToAnyPublisher(),
            $dueDate.map { _ in () }.eraseToAnyPublisher(),
            $color.map { _ in () }.eraseToAnyPublisher(),
            $typedTitle.map { _ in () }.eraseToAnyPublisher()
        )
        .sink { [weak self] in
            self?.applyToTask()
            self?.scheduleSave()
        }
        .store(in: &cancellables)
    }

    private func applyToTask() {
        task.typedTitle = typedTitle
        task.noteText = noteText
        task.status = status
        task.color = color
        task.dueDate = hasDueDate ? dueDate : nil
        // âœ… updatedAt gÃ©rÃ© automatiquement par willSave() dans TaskItem+CoreData.swift
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)  // ✅ 0.25s pour réactivité
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
    
    /// âœ… FIX #2: Save immÃ©diat + MEGA refresh (5 vagues)
    /// UtilisÃ© uniquement pour titleStrokeEnded() afin d'avoir un refresh immÃ©diat du preview PNG
    private func saveNowAndRefresh() {
        ctx.perform { [weak self] in
            guard let self else { return }
            
            do {
                if self.ctx.hasChanges {
                    try self.ctx.save()
                    
                    // âœ… MEGA REFRESH avec 5 vagues pour garantir la mise Ã  jour
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        
                        // Vague 1: ImmÃ©diat
                        self.task.objectWillChange.send()
                        
                        // Force le refresh du contexte Core Data
                        self.ctx.refresh(self.task, mergeChanges: true)
                        
                        // Vague 2: 30ms
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
                            self?.task.objectWillChange.send()
                        }
                        
                        // Vague 3: 80ms
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                            guard let self else { return }
                            self.task.objectWillChange.send()
                            self.ctx.refresh(self.task, mergeChanges: true)
                        }
                        
                        // Vague 4: 150ms
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                            self?.task.objectWillChange.send()
                        }
                        
                        // Vague 5: 300ms (garantie finale)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                            guard let self else { return }
                            self.task.objectWillChange.send()
                            self.ctx.refresh(self.task, mergeChanges: true)
                        }
                    }
                }
            } catch {
                print("âŒ CoreData save error:", error)
            }
        }
    }

    // MARK: - Preview PNG for macOS (iPad only)

    #if os(iOS)
    private func updateTitlePreviewIfNeeded(force: Bool) {
        guard force || titleDrawingData != lastTitlePreviewSource else { return }
        lastTitlePreviewSource = titleDrawingData
        
        let preview = Self.makePreviewPNG(from: titleDrawingData, targetHeight: 96)
        task.titleDrawingPreviewPNG = preview
        
        // âœ… FIX : Force le refresh des rows qui observent la tÃ¢che
        task.objectWillChange.send()
    }

    private func updateBodyPreviewIfNeeded(force: Bool) {
        guard force || bodyDrawingData != lastBodyPreviewSource else { return }
        lastBodyPreviewSource = bodyDrawingData
        task.bodyDrawingPreviewPNG = Self.makePreviewPNG(from: bodyDrawingData, targetHeight: 560)
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

        // Marge optimale
        bounds = bounds.insetBy(dx: -20, dy: -15)
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
            // âœ… Meilleur rendu
            ctx.cgContext.setShouldAntialias(true)
            ctx.cgContext.setAllowsAntialiasing(true)
            ctx.cgContext.interpolationQuality = .high
            
            baseImage.draw(in: CGRect(origin: .zero, size: baseImage.size))
        }

        return img.pngData()
    }
    #endif

    // MARK: - OCR (iOS)

    #if os(iOS)
    private static func ocrBestEffort(image: UIImage, accurate: Bool) -> String {
        let normal = ocr(image: image, accurate: accurate)
        let inverted = ocr(image: invertOnWhite(image: image) ?? image, accurate: accurate)

        return (inverted.trimmingCharacters(in: .whitespacesAndNewlines).count >
                normal.trimmingCharacters(in: .whitespacesAndNewlines).count) ? inverted : normal
    }

    private static func ocr(image: UIImage, accurate: Bool) -> String {
        guard let cg = image.cgImage else { return "" }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = accurate ? .accurate : .fast
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["fr-FR", "en-US"]
        request.minimumTextHeight = 0.012

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do { try handler.perform([request]) }
        catch { return "" }

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

    private static func invertOnWhite(image: UIImage) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = image.scale

        let flattened = UIGraphicsImageRenderer(size: image.size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        guard let ci = CIImage(image: flattened) else { return flattened }

        let invert = CIFilter.colorInvert()
        invert.inputImage = ci

        let controls = CIFilter.colorControls()
        controls.inputImage = invert.outputImage
        controls.saturation = 0
        controls.contrast = 1.20
        controls.brightness = 0

        let context = CIContext(options: nil)
        guard let out = controls.outputImage,
              let cg = context.createCGImage(out, from: out.extent) else {
            return flattened
        }

        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }
    #endif
}
