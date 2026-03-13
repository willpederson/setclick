import SwiftUI
import SwiftData
import CoreHaptics

struct SongsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Song.name) private var songs: [Song]
    @Query private var allEntries: [SetlistEntry]
    @State private var showAddSong = false
    @State private var songToEdit: Song?
    @State private var quickPlaySong: Song?
    @State private var isEditing = false
    @State private var selectedForDeletion: Set<PersistentIdentifier> = []
    
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Songs")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    if !songs.isEmpty {
                        if isEditing {
                            if !selectedForDeletion.isEmpty {
                                Button {
                                    deleteSelected()
                                } label: {
                                    Text("Delete (\(selectedForDeletion.count))")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppTheme.destructive)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 12)
                            }
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditing = false
                                    selectedForDeletion.removeAll()
                                }
                            } label: {
                                Text("Done")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.accent)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { isEditing = true }
                            } label: {
                                Text("Edit")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 12)
                            
                            Button { showAddSong = true } label: {
                                Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.accent)
                                        .frame(width: 40, height: 40)
                                        .glassCircleButton()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                if songs.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(songs) { song in
                                SongCard(
                                    song: song,
                                    isEditing: isEditing,
                                    isSelected: selectedForDeletion.contains(song.persistentModelID),
                                    onEdit: { songToEdit = song },
                                    onPlay: { quickPlaySong = song },
                                    onToggleSelect: {
                                        if selectedForDeletion.contains(song.persistentModelID) {
                                            selectedForDeletion.remove(song.persistentModelID)
                                        } else {
                                            selectedForDeletion.insert(song.persistentModelID)
                                        }
                                    },
                                    onDelete: {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            for entry in allEntries where entry.song?.persistentModelID == song.persistentModelID {
                                                context.delete(entry)
                                            }
                                            context.delete(song)
                                            try? context.save()
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 90)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSong) {
            AddEditSongView()
        }
        .sheet(item: $songToEdit) { song in
            AddEditSongView(song: song)
        }
        .fullScreenCover(item: $quickPlaySong) { song in
            QuickPlayView(song: song)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.08))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "music.note")
                    .font(.system(size: 36))
                    .foregroundColor(AppTheme.accent)
            }
            Text("No songs yet")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
            Text("Add songs with their BPM to get started")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textMuted)
            SCPrimaryButton(title: "Add Song", icon: "plus") {
                showAddSong = true
            }
            .frame(width: 200)
            .padding(.top, 8)
        }
    }
    
    private func deleteSelected() {
        withAnimation(.easeOut(duration: 0.25)) {
            for song in songs where selectedForDeletion.contains(song.persistentModelID) {
                for entry in allEntries where entry.song?.persistentModelID == song.persistentModelID {
                    context.delete(entry)
                }
                context.delete(song)
            }
            try? context.save()
            selectedForDeletion.removeAll()
            isEditing = false
        }
    }
}

struct SongCard: View {
    let song: Song
    var isEditing: Bool = false
    var isSelected: Bool = false
    var onEdit: () -> Void
    var onPlay: () -> Void
    var onToggleSelect: () -> Void = {}
    var onDelete: () -> Void = {}
    
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    private let deleteThreshold: CGFloat = -140
    private let peekThreshold: CGFloat = -50
    
    var body: some View {
        ZStack(alignment: .trailing) {
            if !isEditing && offset < -8 {
                let revealWidth = min(abs(offset), 120)
                let progress = min(1.0, abs(offset) / abs(deleteThreshold))
                
                HStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14 + progress * 8, weight: .bold))
                        if revealWidth > 60 {
                            Text("Delete")
                                .font(.system(size: 11, weight: .bold))
                                .transition(.opacity)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(width: revealWidth)
                    .opacity(0.7 + progress * 0.3)
                }
                .frame(maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(progress >= 0.95 ? Color.red : AppTheme.destructive)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .animation(.interactiveSpring(), value: offset)
            }
            
            // Main card
            HStack(spacing: 14) {
                if isEditing {
                    Button(action: onToggleSelect) {
                        ZStack {
                            Circle()
                                .stroke(isSelected ? AppTheme.destructive : AppTheme.surfaceLight, lineWidth: 2)
                                .frame(width: 26, height: 26)
                            if isSelected {
                                Circle()
                                    .fill(AppTheme.destructive)
                                    .frame(width: 26, height: 26)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Play button
                    Button(action: onPlay) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.12))
                                .frame(width: 48, height: 48)
                            Image(systemName: "play.fill")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(song.timeSignature)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.textMuted)
                        if song.songKeyEnum != .none {
                            Text(song.songKeyEnum.label)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.accent.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AppTheme.accent.opacity(0.1))
                                )
                        }
                        if song.countOffOnly {
                            Image(systemName: "speaker.slash")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        if song.durationSeconds > 0 {
                            Text(song.durationFormatted)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                }
                
                Spacer()
                
                // BPM
                VStack(spacing: 0) {
                    Text("\(song.bpm)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.accent)
                    Text("BPM")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)
                }
                
                if !isEditing {
                    // Edit
                    Button(action: onEdit) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textMuted)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isEditing && isSelected ? AppTheme.destructive.opacity(0.4) : AppTheme.surfaceLight.opacity(0.5),
                                lineWidth: isEditing && isSelected ? 1.5 : 0.5
                            )
                    )
            )
            .offset(x: offset)
            .gesture(
                isEditing ? nil :
                DragGesture(minimumDistance: 18)
                    .onChanged { value in
                        isDragging = true
                        let drag = value.translation.width
                        if drag < 0 {
                            if drag < deleteThreshold {
                                let over = drag - deleteThreshold
                                offset = deleteThreshold + over * 0.25
                            } else {
                                offset = drag
                            }
                        } else if offset < 0 {
                            offset = min(0, offset + drag * 0.5)
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        let drag = value.translation.width
                        let velocity = value.predictedEndTranslation.width
                        
                        if drag < deleteThreshold || velocity < -400 {
                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                offset = -500
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                onDelete()
                            }
                        } else if drag < peekThreshold {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                offset = -90
                            }
                        } else {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                offset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                if offset < -10 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = 0
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}

// MARK: - Quick Play

struct QuickPlayView: View {
    @Environment(\.dismiss) private var dismiss
    let song: Song
    
    @State private var isPlaying = false
    @State private var beatInBar = 0
    @State private var bpmPulse = false
    @State private var hapticEnabled = true
    @StateObject private var engineWrapper = ClickEngineWrapper()
    @State private var hapticEngine: CHHapticEngine?
    @State private var countOffSilenced = false
    
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.textSecondary)
                                .frame(width: 36, height: 36)
                                .glassCircleButton()
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if song.songKeyEnum != .none {
                        Text(song.songKeyEnum.label)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppTheme.accent.opacity(0.12))
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                Text(song.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                
                if countOffSilenced {
                    Text("COUNT-OFF ONLY")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.bottom, 4)
                }
                
                ZStack {
                    Circle()
                        .stroke(AppTheme.accent.opacity(isPlaying ? 0.15 : 0.05), lineWidth: 3)
                        .frame(width: 220, height: 220)
                    
                    ForEach(1...song.timeSignatureEnum.numerator, id: \.self) { beat in
                        let total = song.timeSignatureEnum.numerator
                        let angle = (2 * Double.pi / Double(total)) * Double(beat - 1) - Double.pi / 2
                        let radius: CGFloat = 95
                        Circle()
                            .fill(beatInBar == beat && isPlaying ? (beat == 1 ? AppTheme.accent : .white) : AppTheme.surfaceLight.opacity(0.5))
                            .frame(width: beat == 1 ? 18 : 12, height: beat == 1 ? 18 : 12)
                            .shadow(color: beatInBar == beat && isPlaying ? AppTheme.accent.opacity(0.7) : .clear, radius: 8)
                            .scaleEffect(beatInBar == beat && isPlaying ? 1.4 : 1.0)
                            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: beatInBar)
                            .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                    }
                    
                    VStack(spacing: 2) {
                        Text("\(song.bpm)")
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
                
                Spacer()
                
                Button {
                    if isPlaying {
                        engineWrapper.engine.stop()
                        isPlaying = false
                        beatInBar = 0
                        countOffSilenced = false
                    } else {
                        countOffSilenced = false
                        engineWrapper.engine.setVolume(1.0)
                        engineWrapper.engine.start(
                            bpm: Double(song.bpm),
                            timeSignature: song.timeSignatureEnum,
                            subdivision: song.subdivisionEnum,
                            sound: song.clickSoundEnum,
                            countInBeats: song.countInBeats
                        )
                        isPlaying = true
                    }
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
                .padding(.bottom, 50)
            }
        }
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            prepareHaptics()
            engineWrapper.engine.onTick = { event in
                guard event.generation == engineWrapper.engine.currentGeneration else { return }
                beatInBar = event.beatInBar
                guard event.isBeatBoundary else { return }
                if event.isCountIn { return }
                
                if song.countOffOnly && !countOffSilenced {
                    countOffSilenced = true
                    engineWrapper.engine.setVolume(0)
                }
                
                if hapticEnabled {
                    fireHaptic(strong: event.beatInBar == 1)
                }
                if event.beatInBar == 1 {
                    bpmPulse = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { bpmPulse = false }
                }
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            engineWrapper.engine.stop()
        }
    }
    
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {}
    }
    
    private func fireHaptic(strong: Bool) {
        guard let engine = hapticEngine else {
            UIImpactFeedbackGenerator(style: strong ? .heavy : .light).impactOccurred()
            return
        }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: strong ? 1.0 : 0.4)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: strong ? 0.8 : 0.3)
        let ev = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [ev], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}
