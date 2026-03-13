import SwiftUI
import SwiftData
import UIKit

extension Notification.Name {
    static let setClickImportURL = Notification.Name("setClickImportURL")
}

final class SetClickSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        NotificationCenter.default.post(name: .setClickImportURL, object: url)
    }
}

final class SetClickAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        NotificationCenter.default.post(name: .setClickImportURL, object: url)
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SetClickSceneDelegate.self
        return config
    }
}

@main
struct SetClickApp: App {
    @UIApplicationDelegateAdaptor(SetClickAppDelegate.self) private var appDelegate
    let container: ModelContainer
    @State private var importedSetlistName: String?
    @State private var showImportAlert = false
    @State private var pendingImport: ShareableSetlist?
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showSplash = true
    
    init() {
        let schema = Schema([Song.self, Setlist.self, SetlistEntry.self])
        let config = ModelConfiguration(schema: schema)
        container = try! ModelContainer(for: schema, configurations: config)
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                    ContentView()
                    
                    if showSplash {
                        SplashView()
                            .transition(.opacity)
                            .zIndex(1)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showSplash = false
                                    }
                                }
                            }
                    }
                }
                .preferredColorScheme(.dark)
                .fullScreenCover(isPresented: Binding(get: { !hasSeenOnboarding }, set: { if !$0 { hasSeenOnboarding = true } })) {
                    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .setClickImportURL)) { note in
                    if let url = note.object as? URL {
                        handleIncomingURL(url)
                    }
                }
                .alert("Import Setlist", isPresented: $showImportAlert) {
                    Button("Import") { performImport() }
                    Button("Cancel", role: .cancel) { pendingImport = nil }
                } message: {
                    if let name = importedSetlistName {
                        Text("Add \"\(name)\" to your setlists?")
                    }
                }
        }
        .modelContainer(container)

    }
    

    private func handleIncomingURL(_ url: URL) {
        if url.pathExtension == "setclick" {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url),
                  let setlist = try? JSONDecoder().decode(ShareableSetlist.self, from: data)
            else { return }
            pendingImport = setlist
            importedSetlistName = setlist.name
            showImportAlert = true
        }
    }
    
    @MainActor
    private func performImport() {
        guard let shareable = pendingImport else { return }
        let context = container.mainContext
        
        let newSetlist = Setlist(name: shareable.name)
        context.insert(newSetlist)
        
        for (i, songData) in shareable.songs.enumerated() {
            let song = Song(
                name: songData.name,
                bpm: songData.bpm,
                timeSignature: TimeSignature(rawValue: songData.timeSignature) ?? .fourFour,
                subdivision: Subdivision(rawValue: songData.subdivision) ?? .quarter,
                clickSound: ClickSound(rawValue: songData.clickSound) ?? .classic,
                countInBeats: songData.countInBeats,
                notes: songData.notes,
                durationSeconds: songData.durationSeconds,
                songKey: SongKey(rawValue: songData.songKey) ?? .none,
                countOffOnly: songData.countOffOnly
            )
            song.sections = songData.sections
            context.insert(song)
            
            let entry = SetlistEntry(order: i, song: song, setlist: newSetlist)
            context.insert(entry)
        }
        
        try? context.save()
        pendingImport = nil
    }
}
