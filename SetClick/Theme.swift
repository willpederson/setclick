import SwiftUI

struct AppTheme {
    static let accent = Color(red: 1.0, green: 0.55, blue: 0.0)        // #FF8C00 warm orange
    static let accentDim = Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.6)
    static let background = Color(red: 0.04, green: 0.05, blue: 0.10)  // deep navy-black
    static let surface = Color(red: 0.09, green: 0.11, blue: 0.18)     // card bg
    static let surfaceLight = Color(red: 0.18, green: 0.23, blue: 0.34)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textMuted = Color.white.opacity(0.35)
    static let destructive = Color(red: 0.95, green: 0.3, blue: 0.3)
    
    static var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.01, green: 0.03, blue: 0.10), location: 0.0),
                    .init(color: Color(red: 0.01, green: 0.02, blue: 0.07), location: 0.28),
                    .init(color: Color(red: 0.00, green: 0.01, blue: 0.05), location: 0.62),
                    .init(color: Color(red: 0.00, green: 0.00, blue: 0.02), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.12, green: 0.24, blue: 0.62).opacity(0.32),
                    Color(red: 0.05, green: 0.10, blue: 0.28).opacity(0.16),
                    Color.clear
                ],
                center: UnitPoint(x: 0.16, y: 0.10),
                startRadius: 20,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    Color(red: 0.00, green: 0.40, blue: 0.70).opacity(0.10),
                    Color.clear
                ],
                center: UnitPoint(x: 0.86, y: 0.18),
                startRadius: 10,
                endRadius: 260
            )

            AngularGradient(
                colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.16).opacity(0.0),
                    Color(red: 0.08, green: 0.18, blue: 0.40).opacity(0.10),
                    Color(red: 0.01, green: 0.04, blue: 0.15).opacity(0.0),
                    Color(red: 0.08, green: 0.18, blue: 0.42).opacity(0.08),
                    Color(red: 0.02, green: 0.05, blue: 0.16).opacity(0.0)
                ],
                center: UnitPoint(x: 0.5, y: 0.42)
            )
            .blur(radius: 70)
            .opacity(0.9)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.025),
                    Color.clear,
                    Color(red: 0.14, green: 0.34, blue: 0.70).opacity(0.035),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.screen)

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.10),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
                Spacer()
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.18), Color.black.opacity(0.40)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
        }
    }
}

// MARK: - Custom Components

struct SCTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var lineLimit: Int = 1
    
    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .lineLimit(lineLimit)
            .font(.system(size: 16))
            .foregroundColor(AppTheme.textPrimary)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.surfaceLight, lineWidth: 1)
                    )
            )
    }
}

struct SCSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(AppTheme.accent)
            .tracking(1.5)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }
}

struct SCSegmentedPicker<T: Hashable & Identifiable>: View where T: CustomStringConvertible {
    let items: [T]
    @Binding var selection: T
    var labelForItem: ((T) -> String)? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                let isSelected = item.id as AnyHashable == selection.id as AnyHashable
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = item }
                } label: {
                    Text(labelForItem?(item) ?? item.description)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .black : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? AppTheme.accent : Color.clear)
                        )
                }
                .buttonStyle(SCPressableButtonStyle())
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surface)
        )
    }
}

struct SCStepper: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...999
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            HStack(spacing: 0) {
                Button {
                    if value > range.lowerBound { value -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(SCPressableButtonStyle())
                
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(minWidth: 36)
                
                Button {
                    if value < range.upperBound { value += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(SCPressableButtonStyle())
            }
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.surface)
            )
        }
    }
}

struct SCCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.surfaceLight.opacity(0.92), AppTheme.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.32), radius: 10, y: 6)
        )
    }
}

struct SCPrimaryButton: View {
    let title: String
    let icon: String?
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    isDestructive ? AppTheme.destructive : AppTheme.accent
                    LinearGradient(
                        colors: [Color.white.opacity(0.20), Color.clear],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: (isDestructive ? AppTheme.destructive : AppTheme.accent).opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(SCPressableButtonStyle(scale: 0.985, pressedOpacity: 0.96))
    }
}


struct SCPressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var pressedOpacity: Double = 0.92
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Glass Effect Compatibility

extension View {
    @ViewBuilder
    func glassCircleButton() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .circle)
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }
}
