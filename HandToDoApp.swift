import SwiftUI
import CoreData

@main
struct HandToDoApp: App {
    @StateObject private var persistence = PersistenceController.shared
    @StateObject private var localization = LocalizationManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .environmentObject(persistence)
                .environmentObject(localization)
                .environment(\.locale, localization.language.locale)
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentSize)
        #endif
    }
}

private struct RootView: View {
    @EnvironmentObject private var persistence: PersistenceController

    @State private var didLoad = false

    var body: some View {
        Group {
            if persistence.isLoaded {
                ContentView()
            } else {
                // ✅ LoadingShell avec nouveau design dès le début
                LoadingShellView()
            }
        }
        .task {
            if !didLoad {
                didLoad = true
                persistence.loadIfNeeded()
            }
        }
    }
}

// ✨ LoadingShellView REDESIGNED - Même design que ContentView
private struct LoadingShellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        NavigationSplitView {
            List {
                Section { EmptyView() } header: {
                    // ✨ Section header avec gradient (même style que ContentView)
                    sectionHeader(
                        icon: "circle",
                        title: loc.tr("status.todo"),
                        gradient: .todoGradient,
                        count: 0
                    )
                }
                Section { EmptyView() } header: {
                    sectionHeader(
                        icon: "bolt.fill",
                        title: loc.tr("status.doing"),
                        gradient: .doingGradient,
                        count: 0
                    )
                }
                Section { EmptyView() } header: {
                    sectionHeader(
                        icon: "checkmark.circle.fill",
                        title: loc.tr("status.done"),
                        gradient: .doneGradient,
                        count: 0
                    )
                }
            }
            #if os(macOS)
            .listStyle(.sidebar)
            #else
            .listStyle(.insetGrouped)
            #endif
            .scrollContentBackground(.hidden)  // ✅ Masque le background par défaut
            .background(LinearGradient.backgroundGradient(colorScheme))  // ✅ Gradient dès le début
            .navigationTitle(loc.tr("app.title"))
        } detail: {
            // ✨ Dashboard avec nouveau design
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.primaryGradient)
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.primaryStart.opacity(0.3), radius: 16, y: 8)
                    
                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white)
                }
                
                Text(loc.tr("dashboard.selectTask"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primaryText(colorScheme))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LinearGradient.backgroundGradient(colorScheme))  // ✅ Gradient dès le début
        }
        .tint(.primary)
    }
    
    // ✨ Section Header (même style que ContentView)
    private func sectionHeader(icon: String, title: String, gradient: LinearGradient, count: Int) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(gradient)
                    .frame(width: 28, height: 28)
                    .shadow(color: gradient.shadowColor, radius: 4, y: 2)
                
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.primaryText(colorScheme))
            
            Spacer()
            
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(gradient)
                    .clipShape(Capsule())
                    .shadow(color: gradient.shadowColor, radius: 4, y: 2)
            }
        }
        .padding(.vertical, 6)
    }
}
