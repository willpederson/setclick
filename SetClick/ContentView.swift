import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SongsView()
                .contentShape(Rectangle())
                .gesture(tabSwipeGesture)
                .tabItem {
                    Label("Songs", systemImage: "music.note.list")
                }
                .tag(0)
            SetlistsView()
                .contentShape(Rectangle())
                .gesture(tabSwipeGesture)
                .tabItem {
                    Label("Setlists", systemImage: "list.bullet.rectangle.portrait")
                }
                .tag(1)
        }
        .tint(AppTheme.accent)
    }
    
    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical), abs(horizontal) > 60 else { return }
                
                if horizontal < 0, selectedTab < 1 {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedTab += 1
                    }
                } else if horizontal > 0, selectedTab > 0 {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedTab -= 1
                    }
                }
            }
    }
}
