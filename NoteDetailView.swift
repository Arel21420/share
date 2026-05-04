import SwiftUI
import CoreData
#if os(macOS)
import AppKit
#endif

/// âœ¨ NoteDetailView REDESIGNED - Version WOW avec gradients
/// âœ… MÃªme design que TaskDetailView
struct NoteDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var loc: LocalizationManager

    @ObservedObject var note: NoteItem
    @Binding var selectionID: NSManagedObjectID?

    @StateObject private var vm: NoteDetailViewModel

    @State private var confirmClearTitle = false
    @State private var confirmClearBody = false

    init(note: NoteItem, selectionID: Binding<NSManagedObjectID?>) {
        self.note = note
        self._selectionID = selectionID
        _vm = StateObject(wrappedValue: NoteDetailViewModel(ctx: note.managedObjectContext!, note: note))
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
        .navigationTitle(loc.tr("notes.navTitle"))
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onDisappear { vm.onDisappear() }  // ✅ INSTANT PREVIEW : Génère PNG avant de quitter
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    selectionID = nil
                } label: {
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

        .onChange(of: vm.noteText) { _, _ in vm.commitLight() }

        .alert(loc.tr("notes.hand.title.clear.confirmTitle"), isPresented: $confirmClearTitle) {
            Button(loc.tr("common.cancel"), role: .cancel) {}
            Button(loc.tr("common.delete"), role: .destructive) { vm.clearTitleDrawing() }
        } message: {
            Text(loc.tr("notes.hand.title.clear.confirmMsg"))
        }

        .alert(loc.tr("notes.hand.body.clear.confirmTitle"), isPresented: $confirmClearBody) {
            Button(loc.tr("common.cancel"), role: .cancel) {}
            Button(loc.tr("common.delete"), role: .destructive) { vm.clearBodyDrawing() }
        } message: {
            Text(loc.tr("notes.hand.body.clear.confirmMsg"))
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Titre avec icÃ´ne gradient
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient.primaryGradient)
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.primaryStart.opacity(0.3), radius: 8, y: 4)
                    
                    Image(systemName: "note.text")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                // âœ… AJOUT: Contour du champ titre
                TextField(
                    loc.tr("notes.typedTitle.placeholder"),
                    text: typedTitleBinding,
                    axis: .vertical
                )
                .font(.title2.weight(.semibold))
                .lineLimit(1...3)
                .foregroundStyle(Color.primaryText(colorScheme))
                .padding(12)  // âœ… Padding pour le contour
                .background(Color.tertiaryBackground(colorScheme))  // âœ… Background
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))  // âœ… Coins arrondis
                .overlay(  // âœ… CONTOUR
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primaryText(colorScheme).opacity(0.15), lineWidth: 1.5)
                )
            }

            Divider()
                .background(Color.primaryText(colorScheme).opacity(0.2))

            // âœ… AJOUT: Spacing de 12 avant la note
            Spacer()
                .frame(height: 12)

            // Note section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LinearGradient.primaryGradient)
                    
                    Text(loc.tr("notes.note.label"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.secondaryText(colorScheme))
                }

                TextEditor(text: $vm.noteText)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(Color.tertiaryBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primaryText(colorScheme).opacity(0.1), lineWidth: 1)
                    )
            }
        }
        .padding(20)
        .background(Color.cardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(
            color: colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.08),
            radius: 16,
            y: 8
        )
    }

    // MARK: - Title Handwriting Card

    private var titleHandwritingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // âœ… Header EXACTEMENT comme PJ - IcÃ´ne carrÃ©e + texte
            HStack(spacing: 12) {
                // âœ… IcÃ´ne carrÃ©e arrondie GRANDE (comme PJ)
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient.primaryGradient)  // Violet/bleu
                        .frame(width: 32, height: 32)  //ICI âœ… 48x48 comme PJ
                        .shadow(color: Color.primaryStart.opacity(0.3), radius: 8, y: 4)
                    
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 16, weight: .bold))//.font(.system(size: 20, weight: .semibold))  // âœ… Plus gros
                        .foregroundStyle(.white)
                }
                
                Text(loc.tr("notes.hand.title.label"))
                    .font(.subheadline.weight(.semibold))// .font(.headline)  // ICI .font(.body.weight(.semibold))  // âœ… Body comme PJ
                    .foregroundStyle(Color.primaryText(colorScheme))
                
                Spacer()

                // Actions - Cercles colorÃ©s comme PJ
                HStack(spacing: 12) {
                    Button {
                        confirmClearTitle = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
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
            }

            // âœ… Canvas avec CONTOUR TRÃˆS VISIBLE (comme PJ)
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
            .background(Color.tertiaryBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(  // âœ… CONTOUR Ã‰PAIS BLEU comme PJ
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LinearGradient.primaryGradient, lineWidth: 2)  // âœ… 3px bleu ! ICI
            )

            // Texte reconnu
            if !vm.recognizedTitle.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 12))
                        .foregroundStyle(LinearGradient.primaryGradient)
                    
                    Text("\(loc.tr("notes.hand.recognized.prefix")) \(vm.recognizedTitle)")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText(colorScheme))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.tertiaryBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(20)
        .background(Color.cardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(
            color: colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.08),
            radius: 16,
            y: 8
        )
    }

    @ViewBuilder
    private var titlePreviewView: some View {
        #if os(macOS)
        if let png = note.titleDrawingPreviewPNG,
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
                    .foregroundStyle(Color.secondaryText(colorScheme))
                Text(loc.tr("notes.hand.recognized.empty"))
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText(colorScheme))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #else
        EmptyView()
        #endif
    }

    // MARK: - Body Handwriting Card

    private var bodyHandwritingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // âœ… Header EXACTEMENT comme PJ - IcÃ´ne carrÃ©e orange + texte
            HStack(spacing: 12) {
                // âœ… IcÃ´ne carrÃ©e arrondie GRANDE orange (comme PJ)
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient.doingGradient)  // Orange
                        .frame(width: 32, height: 32)  // ICI âœ… 48x48 comme PJ
                        .shadow(color: Color.doingStart.opacity(0.3), radius: 8, y: 4)
                    
                    Image(systemName: "pencil.tip") //note.text
                        .font(.system(size: 14, weight: .semibold))  // âœ… Plus gros
                        .foregroundStyle(.white)
                }
                
                Text(loc.tr("notes.hand.body.label"))
                    .font(.subheadline.weight(.semibold))//.font(.headline) // ICI .font(.body.weight(.semibold))  // âœ… Body comme PJ
                    .foregroundStyle(Color.primaryText(colorScheme))
                
                Spacer()

                Button {
                    confirmClearBody = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help(loc.tr("common.delete"))
            }

            // âœ… Canvas avec GRADIENT ROUGE-ORANGE (comme PJ)
            Group {
                if canEditHandwriting {
                    PencilCanvas(drawingData: $vm.bodyDrawingData, onEndStroke: {
                        vm.bodyStrokeEnded()
                    })
                    .frame(height: 560)
                } else {
                    bodyPreviewView
                        .frame(height: 560)
                }
            }
            .background(Color.tertiaryBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(  // âœ… CONTOUR Ã‰PAIS GRADIENT rouge-orange comme PJ
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.red, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3  // âœ… 3px Ã©pais !
                    )
            )
        }
        .padding(20)
        .background(Color.cardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(
            color: colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.08),
            radius: 16,
            y: 8
        )
    }

    @ViewBuilder
    private var bodyPreviewView: some View {
        #if os(macOS)
        if let png = note.bodyDrawingPreviewPNG,
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
                    .foregroundStyle(Color.secondaryText(colorScheme))
                Text("â€”")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText(colorScheme))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #else
        EmptyView()
        #endif
    }
}
