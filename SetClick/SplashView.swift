import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.4
    @State private var logoOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0
    @State private var finished = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.06, blue: 0.12), Color(red: 0.03, green: 0.03, blue: 0.05)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
            
            VStack(spacing: 16) {
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(AppTheme.accent.opacity(0.3), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                        .blur(radius: 2)
                    
                    // Inner glow
                    Circle()
                        .fill(AppTheme.accent.opacity(0.08))
                        .frame(width: 100, height: 100)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                    
                    // Metronome icon
                    Image(systemName: "metronome.fill")
                        .font(.system(size: 44))
                        .foregroundColor(AppTheme.accent)
                        .shadow(color: AppTheme.accent.opacity(0.6), radius: glowRadius)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }
                
                Text("SetClick")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            // Logo scales up with bounce
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            // Ring expands
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2)) {
                ringScale = 1.0
                ringOpacity = 1.0
            }
            // Glow pulses
            withAnimation(.easeInOut(duration: 0.4).delay(0.3)) {
                glowRadius = 20
            }
            withAnimation(.easeInOut(duration: 0.3).delay(0.7)) {
                glowRadius = 8
            }
            // Text fades in
            withAnimation(.easeOut(duration: 0.3).delay(0.4)) {
                textOpacity = 1.0
            }
            // Dismiss after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    finished = true
                }
            }
        }
        .opacity(finished ? 0 : 1)
        .scaleEffect(finished ? 1.1 : 1.0)
    }
    
}
