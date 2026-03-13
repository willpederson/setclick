import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0
    
    private let pages: [(icon: String, title: String, subtitle: String)] = [
        ("metronome.fill", "Welcome to SetClick", "Your stage-ready click track companion.\nBuilt for drummers, by a drummer."),
        ("music.note", "Build Your Library", "Create songs with BPM, time signature, key,\nand custom click settings."),
        ("list.bullet.rectangle.portrait", "Organize for the Gig", "Group songs into setlists to keep\nyour set tight and in order."),
        ("play.circle.fill", "Go Live", "Play through your setlist with beat visualization,\nhaptics, and lock screen controls.")
    ]
    
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        onboardingPage(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 380)
                
                // Dot indicators
                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? AppTheme.accent : AppTheme.surfaceLight)
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Bottom button
                if currentPage == pages.count - 1 {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            hasSeenOnboarding = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Get Started")
                                .font(.system(size: 18, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: AppTheme.accent.opacity(0.35), radius: 12, y: 6)
                    }
                    .buttonStyle(SCPressableButtonStyle(scale: 0.985, pressedOpacity: 0.96))
                    .padding(.horizontal, 32)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage += 1
                        }
                    } label: {
                        Text("Next")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(AppTheme.accent.opacity(0.06))
                                    )
                            )
                    }
                    .buttonStyle(SCPressableButtonStyle(scale: 0.985, pressedOpacity: 0.97))
                    .padding(.horizontal, 32)
                }
                
                // Skip
                if currentPage < pages.count - 1 {
                    Button {
                        hasSeenOnboarding = true
                    } label: {
                        Text("Skip")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                }
                
                Spacer().frame(height: 50)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentPage)
    }
    
    private func onboardingPage(_ page: (icon: String, title: String, subtitle: String)) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.08))
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: page.icon)
                    .font(.system(size: 44))
                    .foregroundColor(AppTheme.accent)
                    .shadow(color: AppTheme.accent.opacity(0.4), radius: 12)
            }
            
            Text(page.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            
            Text(page.subtitle)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 24)
        }
        .padding(.horizontal, 20)
    }
}
