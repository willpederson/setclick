import SwiftUI
import SwiftData
import Combine
import CoreHaptics
import MediaPlayer
import AVFoundation

struct LiveModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.scenePhase) private var scenePhase
    let setlist: Setlist
    @Query(sort: \Song.name) private var allSongs: [Song]
    
    @State private var currentIndex = 0
    @State private var isPlaying = false
    @State private var beatInBar = 0
    @State private var isCountIn = false
    @State private var countInRemaining = 0
    @State private var flashOpacity: Double = 0
    @State private var hapticEnabled = true
    @State private var flashEnabled = true
    @State private var countOffSilenced = false
    
    // Auto-advance
    @State private var elapsedSeconds = 0
    @State private var autoAdvanceTimer: Timer?
    
    // Animations
    @State private var bpmPulse = false
    @State private var beatScale: CGFloat = 1.0
    
    @StateObject private var engineWrapper = ClickEngineWrapper()
    @State private var hapticEngine: CHHapticEngine?
    @State private var showExitConfirmation = false
    @State private var interruptionMessage: String?
    @State private var routeMessage: String?
    
    private var validSongIDs: Set<PersistentIdentifier> {
        Set(allSongs.map { $0.persistentModelID })
    }
    private var entries: [SetlistEntry] {
        setlist.sortedEntries.filter { entry in
            guard let song = entry.song else { return false }
            return validSongIDs.contains(song.persistentModelID)
        }
    }
    private var currentSong: Song? {
        guard currentIndex < entries.count else { return nil }
        return entries[currentIndex].song
    }
    private var nextSong: Song? {
        let nextIndex = currentIndex + 1
        guard nextIndex < entries.count else { return nil }
        return entries[nextIndex].song
    }
    private var activeBPM: Int { currentSong?.bpm ?? 120 }
    private var activeTimeSig: TimeSignature { currentSong?.timeSignatureEnum ?? .fourFour }
    
    var body: some View {
        ZStack {
                        Color.black.ignoresSafeArea()
            
            AppTheme.accent.opacity(flashOpacity).ignoresSafeArea()
                .allowsHitTesting(false)
            
            if vSizeClass == .compact {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            prepareHaptics()
            setupEngine()
            setupNowPlaying()
        }
        .alert("Exit Live Mode?", isPresented: $showExitConfirmation) {
            Button("Keep Playing", role: .cancel) {}
            Button("Exit", role: .destructive) {
                stopPlayback()
                dismiss()
            }
        } message: {
            Text("This will stop the click and leave Live Mode.")
        }
        .alert("Playback Interrupted", isPresented: Binding(get: { interruptionMessage != nil }, set: { if !$0 { interruptionMessage = nil } })) {
            Button("OK", role: .cancel) { interruptionMessage = nil }
        } message: {
            Text(interruptionMessage ?? "")
        }
        .alert("Audio Output Changed", isPresented: Binding(get: { routeMessage != nil }, set: { if !$0 { routeMessage = nil } })) {
            Button("OK", role: .cancel) { routeMessage = nil }
        } message: {
            Text(routeMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            handleAudioInterruption(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
            handleRouteChange(notification)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            engineWrapper.engine.stop()
            autoAdvanceTimer?.invalidate()
            clearNowPlaying()
        }
    }
    
    // MARK: - Portrait
    
    private var portraitLayout: some View {
        VStack(spacing: 0) {
            topBar
            
            Spacer()
            
            // Song name + key
            if let song = currentSong {
                VStack(spacing: 8) {
                    Text(song.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    if let nextSong = nextSong {
                        HStack(spacing: 6) {
                            Text("NEXT")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.3)
                                .foregroundColor(AppTheme.textMuted)
                            Text(nextSong.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surface))
                    }
                    
                    HStack(spacing: 10) {
                        if song.songKeyEnum != .none {
                            Text(song.songKeyEnum.label)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(AppTheme.accent.opacity(0.12))
                                )
                        }
                        if song.countOffOnly {
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.slash")
                                    .font(.system(size: 10))
                                Text("COUNT-OFF")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1)
                            }
                            .foregroundColor(countOffSilenced ? AppTheme.textMuted : AppTheme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            beatRingView
                .padding(.vertical, 8)
            
            songProgressView
            
            if isCountIn {
                Text("COUNT IN: \(countInRemaining)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.accent)
                    .padding(.top, 8)
                    .transition(.scale.combined(with: .opacity))
            }
            
            autoAdvanceView
            notesView
            
            Spacer()
            
            toggleRow
                .padding(.bottom, 8)
            controls
        }
    }
    
    // MARK: - Landscape
    
    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            topBar
            
            HStack(spacing: 0) {
                VStack {
                    Spacer()
                    if let song = currentSong {
                        VStack(spacing: 6) {
                            Text(song.name)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                            if let nextSong = nextSong {
                                Text("Next: \(nextSong.name)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            if song.songKeyEnum != .none {
                                Text(song.songKeyEnum.label)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                    }
                    Spacer()
                    beatRingView.scaleEffect(0.8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Spacer()
                    toggleRow.padding(.bottom, 8)
                    controls
                }
                .frame(width: 280)
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button {
                if isPlaying {
                    showExitConfirmation = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .glassCircleButton()
            }
            .buttonStyle(.plain)
            Spacer()
            Text(setlist.name.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.textMuted)
                .tracking(2)
            Spacer()
            Text("\(currentIndex + 1)/\(entries.count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surface))
        }
        .padding()
    }
    
    // MARK: - Beat Ring
    
    private var beatRingView: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.accent.opacity(isPlaying ? 0.15 : 0.05), lineWidth: 3)
                .frame(width: 220, height: 220)
            
            ForEach(1...activeTimeSig.numerator, id: \.self) { beat in
                let total = activeTimeSig.numerator
                let angle = (2 * Double.pi / Double(total)) * Double(beat - 1) - Double.pi / 2
                let radius: CGFloat = 95
                
                Circle()
                    .fill(beatInBar == beat && isPlaying ?
                          (beat == 1 ? AppTheme.accent : .white) :
                          AppTheme.surfaceLight.opacity(0.5))
                    .frame(width: beat == 1 ? 18 : 12, height: beat == 1 ? 18 : 12)
                    .shadow(color: beatInBar == beat && isPlaying ? AppTheme.accent.opacity(0.7) : .clear, radius: 8)
                    .scaleEffect(beatInBar == beat && isPlaying ? 1.4 : 1.0)
                    .animation(.spring(response: 0.15, dampingFraction: 0.5), value: beatInBar)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }
            
            VStack(spacing: 2) {
                Text("\(activeBPM)")
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.accent)
                    .shadow(color: AppTheme.accent.opacity(bpmPulse ? 0.5 : 0.0), radius: bpmPulse ? 16 : 0)
                    .scaleEffect(bpmPulse ? 1.04 : 1.0)
                    .animation(.easeOut(duration: 0.12), value: bpmPulse)
                Text("BPM")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .frame(width: 240, height: 240)
    }
    
    // MARK: - Song Progress
    
    @ViewBuilder
    private var songProgressView: some View {
        if let song = currentSong, song.durationSeconds > 0, isPlaying {
            let progress = Double(elapsedSeconds) / Double(song.durationSeconds)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.surfaceLight.opacity(0.4))
                    Capsule()
                        .fill(AppTheme.accent)
                        .frame(width: geo.size.width * min(1.0, max(0.02, progress)))
                        .animation(.linear(duration: 0.5), value: elapsedSeconds)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Auto Advance
    
    @ViewBuilder
    private var autoAdvanceView: some View {
        if let song = currentSong, isPlaying, song.durationSeconds > 0 {
            let remaining = max(0, song.durationSeconds - elapsedSeconds)
            VStack(spacing: 4) {
                Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(remaining < 10 ? AppTheme.destructive : AppTheme.textSecondary)
                Text("remaining")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.1)
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.top, 6)
        }
    }
    
    // MARK: - Notes
    
    @ViewBuilder
    private var notesView: some View {
        if let song = currentSong, !song.notes.isEmpty {
            Text(song.notes)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)
                .lineLimit(2)
        }
    }
    
    // MARK: - Toggles
    
    private var toggleRow: some View {
        HStack(spacing: 28) {
            toggleButton(icon: hapticEnabled ? "iphone.radiowaves.left.and.right" : "iphone.slash",
                        active: hapticEnabled) { hapticEnabled.toggle() }
            toggleButton(icon: flashEnabled ? "bolt.fill" : "bolt.slash",
                        active: flashEnabled) { flashEnabled.toggle() }
        }
    }
    
    private func toggleButton(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(active ? AppTheme.accent : AppTheme.textMuted)
                .frame(width: 44, height: 44)
                .background(active ? AppTheme.accent.opacity(0.12) : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Controls
    
    private var controls: some View {
        HStack(spacing: 40) {
            Button {
                switchSong(delta: -1)
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundColor(currentIndex > 0 ? AppTheme.textSecondary : AppTheme.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(currentIndex == 0)
            
            Button {
                togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(isPlaying ? AppTheme.destructive.opacity(0.25) : AppTheme.accent.opacity(0.25))
                        .frame(width: 100, height: 100)
                        .blur(radius: 12)
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.black)
                        .frame(width: 76, height: 76)
                        .background(isPlaying ? AppTheme.destructive : AppTheme.accent)
                        .clipShape(Circle())
                }
            }
            .buttonStyle(.plain)
            
            Button {
                switchSong(delta: 1)
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundColor(currentIndex < entries.count - 1 ? AppTheme.textSecondary : AppTheme.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(currentIndex >= entries.count - 1)
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Engine
    
    private func setupEngine() {
        engineWrapper.engine.onTick = { event in
            guard event.generation == self.engineWrapper.engine.currentGeneration else { return }
            
            self.beatInBar = event.beatInBar
            self.isCountIn = event.isCountIn
            self.countInRemaining = event.countInRemaining
            
            guard event.isBeatBoundary && !event.isCountIn else { return }
            
            // Count-off mode: mute after count-in finishes
            if let song = currentSong, song.countOffOnly && !countOffSilenced {
                countOffSilenced = true
                engineWrapper.engine.setVolume(0)
            }
            
            if hapticEnabled {
                fireHaptic(strong: event.beatInBar == 1)
            }
            
            if event.beatInBar == 1 {
                bpmPulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    bpmPulse = false
                }
                
                if flashEnabled {
                    withAnimation(.easeOut(duration: 0.05)) { flashOpacity = 0.15 }
                    withAnimation(.easeOut(duration: 0.2).delay(0.05)) { flashOpacity = 0 }
                }
            }
        }
    }
    
    private func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        
        switch type {
        case .began:
            if isPlaying {
                stopPlayback()
                interruptionMessage = "Playback stopped because audio was interrupted."
            }
        case .ended:
            try? AVAudioSession.sharedInstance().setActive(true)
            prepareHaptics()
            updateNowPlaying()
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawReason = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else { return }
        
        switch reason {
        case .oldDeviceUnavailable:
            if isPlaying {
                stopPlayback()
                routeMessage = "Audio output changed. Playback stopped to avoid blasting the click on the wrong speaker."
            }
        case .newDeviceAvailable, .routeConfigurationChange, .override:
            updateNowPlaying()
        default:
            break
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            try? AVAudioSession.sharedInstance().setActive(true)
            prepareHaptics()
            updateNowPlaying()
        case .inactive, .background:
            updateNowPlaying()
        @unknown default:
            break
        }
    }

    // MARK: - Playback
    
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startCurrentSong()
        }
    }
    
    private func startCurrentSong() {
        guard let song = currentSong else { return }
        elapsedSeconds = 0
        countOffSilenced = false
        
        // Reset volume in case previous song was count-off
        engineWrapper.engine.setVolume(1.0)
        
        engineWrapper.engine.start(
            bpm: Double(activeBPM),
            timeSignature: activeTimeSig,
            subdivision: song.subdivisionEnum,
            sound: song.clickSoundEnum,
            countInBeats: song.countInBeats
        )
        withAnimation(.easeOut(duration: 0.2)) {
            isPlaying = true
        }
        updateNowPlaying()
        
        if song.durationSeconds > 0 {
            let songDuration = song.durationSeconds
            autoAdvanceTimer?.invalidate()
            autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                elapsedSeconds += 1
                if elapsedSeconds >= songDuration {
                    autoAdvanceTimer?.invalidate()
                    autoAdvanceTimer = nil
                    stopPlayback()
                }
            }
        }
    }
    
    private func stopPlayback() {
        engineWrapper.engine.stop()
        withAnimation(.easeOut(duration: 0.2)) {
            isPlaying = false
        }
        beatInBar = 0
        isCountIn = false
        countOffSilenced = false
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
        updateNowPlaying()
    }
    
    private func switchSong(delta: Int) {
        let newIndex = currentIndex + delta
        guard newIndex >= 0, newIndex < entries.count else { return }
        stopPlayback()
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex = newIndex
        }
        updateNowPlaying()
    }
    
    // MARK: - Now Playing
    
    private func setupNowPlaying() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { _ in
            if !isPlaying { startCurrentSong() }
            return .success
        }
        commandCenter.pauseCommand.addTarget { _ in
            if isPlaying { stopPlayback() }
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            togglePlayback()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { _ in
            if currentIndex < entries.count - 1 { switchSong(delta: 1) }
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { _ in
            if currentIndex > 0 { switchSong(delta: -1) }
            return .success
        }
        updateNowPlaying()
    }
    
    private func updateNowPlaying() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentSong?.name ?? "SetClick"
        info[MPMediaItemPropertyArtist] = "\(activeBPM) BPM"
        info[MPMediaItemPropertyAlbumTitle] = setlist.name
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if let song = currentSong, song.durationSeconds > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = Double(song.durationSeconds)
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(elapsedSeconds)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.removeTarget(nil)
        cc.pauseCommand.removeTarget(nil)
        cc.togglePlayPauseCommand.removeTarget(nil)
        cc.nextTrackCommand.removeTarget(nil)
        cc.previousTrackCommand.removeTarget(nil)
    }
    
    // MARK: - Haptics
    
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            hapticEngine?.resetHandler = { try? self.hapticEngine?.start() }
        } catch {}
    }
    
    private func fireHaptic(strong: Bool) {
        guard let engine = hapticEngine else {
            let gen = UIImpactFeedbackGenerator(style: strong ? .heavy : .light)
            gen.impactOccurred()
            return
        }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: strong ? 1.0 : 0.4)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: strong ? 0.8 : 0.3)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}

class ClickEngineWrapper: ObservableObject {
    let engine = ClickEngine()
}
