import SwiftUI

/// ✨ Custom Segmented Control REDESIGNED
/// Plus joli que le Picker standard
struct CustomSegmentedControl: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let tabs: [String]
    @Binding var selection: Int
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = index
                    }
                } label: {
                    Text(tab)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selection == index ? .white : Color.primaryText(colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                if selection == index {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(LinearGradient.primaryGradient)
                                        .shadow(
                                            color: Color.primaryStart.opacity(0.3),
                                            radius: 8,
                                            y: 4
                                        )
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.tertiaryBackground(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primaryText(colorScheme).opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selection = 0
        
        var body: some View {
            VStack(spacing: 20) {
                CustomSegmentedControl(
                    tabs: ["Tâches", "Notes"],
                    selection: $selection
                )
                .padding()
                
                Text("Selected: \(selection)")
            }
            .preferredColorScheme(.dark)
        }
    }
    
    return PreviewWrapper()
}
