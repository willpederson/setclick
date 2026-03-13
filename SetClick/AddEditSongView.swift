import SwiftUI
import SwiftData

struct AddEditSongView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    var song: Song?
    
    @State private var name = ""
    @State private var bpm = 120
    @State private var timeSignature: TimeSignature = .fourFour
    @State private var subdivision: Subdivision = .quarter
    @State private var clickSound: ClickSound = .classic
    @State private var countInBeats = 4
    @State private var notes = ""
    @State private var durationMinutes = 0
    @State private var durationSecs = 0
    @State private var songKey: SongKey = .none
    @State private var countOffOnly = false
    
    @State private var tapTimes: [Date] = []
    @State private var tapBPM: Int?
    @State private var tapScale: CGFloat = 1.0
    
    private var isEditing: Bool { song != nil }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var totalDuration: Int { durationMinutes * 60 + durationSecs }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        songIdentityCard
                        tempoCard
                        clickSettingsCard
                        modeAndDurationCard
                        notesCard
                        Spacer().frame(height: 36)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            if let song {
                name = song.name
                bpm = song.bpm
                timeSignature = song.timeSignatureEnum
                subdivision = song.subdivisionEnum
                clickSound = song.clickSoundEnum
                countInBeats = song.countInBeats
                notes = song.notes
                durationMinutes = song.durationSeconds / 60
                durationSecs = song.durationSeconds % 60
                songKey = song.songKeyEnum
                countOffOnly = song.countOffOnly
            }
        }
    }
    
    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .buttonStyle(SCPressableButtonStyle())
            
            Spacer()
            
            Text(isEditing ? "Edit Song" : "New Song")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
            
            Spacer()
            
            Button { save() } label: {
                Text("Save")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(trimmedName.isEmpty ? AppTheme.textMuted : AppTheme.accent)
            }
            .buttonStyle(SCPressableButtonStyle())
            .disabled(trimmedName.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var songIdentityCard: some View {
        SCCard {
            cardHeader(title: "Song Identity", icon: "music.note")
            
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Song Name")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                    SCTextField(placeholder: "Song name", text: $name)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                    keyPicker
                }
            }
        }
    }
    
    private var tempoCard: some View {
        SCCard {
            HStack(alignment: .top) {
                cardHeader(title: "Tempo", icon: "metronome")
                Spacer()
                if let tapBPM {
                    statBadge("Detected \(tapBPM)")
                }
            }
            
            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    heroTempoButton(systemImage: "minus") {
                        if bpm > 20 { bpm -= 1 }
                    }
                    
                    VStack(spacing: 2) {
                        Text("\(bpm)")
                            .font(.system(size: 68, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("BEATS PER MINUTE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.6)
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    
                    heroTempoButton(systemImage: "plus") {
                        if bpm < 300 { bpm += 1 }
                    }
                }
                
                tapTempoButton
                bpmQuickActions
            }
        }
    }
    
    private var clickSettingsCard: some View {
        SCCard {
            cardHeader(title: "Click Settings", icon: "dial.high")
            
            VStack(alignment: .leading, spacing: 16) {
                settingGroup(title: "Time Signature") {
                    SCSegmentedPicker(items: TimeSignature.allCases, selection: $timeSignature)
                }
                
                settingGroup(title: "Subdivision") {
                    SCSegmentedPicker(items: Subdivision.allCases, selection: $subdivision)
                }
                
                settingGroup(title: "Sound") {
                    SCSegmentedPicker(items: ClickSound.allCases, selection: $clickSound)
                }
                
                SCStepper(label: "Count-in beats", value: $countInBeats, range: 0...8)
            }
        }
    }
    
    private var modeAndDurationCard: some View {
        SCCard {
            cardHeader(title: "Playback", icon: "speaker.wave.2")
            
            VStack(alignment: .leading, spacing: 16) {
                countOffToggle
                durationPicker
            }
        }
    }
    
    private var notesCard: some View {
        SCCard {
            cardHeader(title: "Notes", icon: "text.alignleft")
            Text("Keep cues short and glanceable for stage use.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textMuted)
            SCTextField(placeholder: "e.g. soft intro, build at chorus", text: $notes, axis: .vertical, lineLimit: 4)
        }
    }
    
    private func cardHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.accent)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
                .foregroundColor(AppTheme.accent)
        }
    }
    
    private func statBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.06)))
    }
    
    private func settingGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
            content()
        }
    }
    
    private func heroTempoButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AppTheme.surface.opacity(0.95))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                    )
                    .frame(width: 54, height: 54)
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.accent)
            }
        }
        .buttonStyle(SCPressableButtonStyle())
    }
    
    private var bpmQuickActions: some View {
        HStack(spacing: 8) {
            bpmQuickButton("-5") { bpm = max(20, bpm - 5) }
            bpmQuickButton("-1") { bpm = max(20, bpm - 1) }
            bpmQuickButton("+1") { bpm = min(300, bpm + 1) }
            bpmQuickButton("+5") { bpm = min(300, bpm + 5) }
            Spacer(minLength: 8)
            Button {
                bpm = 120
            } label: {
                Text("Reset")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.05))
                    )
            }
             .buttonStyle(SCPressableButtonStyle())
        }
    }
    
    private func bpmQuickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                )
        }
        .buttonStyle(SCPressableButtonStyle())
    }
    
    private var tapTempoButton: some View {
        Button {
            recordTap()
            withAnimation(.easeOut(duration: 0.1)) { tapScale = 0.94 }
            withAnimation(.spring(response: 0.2).delay(0.08)) { tapScale = 1.0 }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 16))
                Text(tapBPM != nil ? "Tap Tempo (\(tapBPM!) BPM)" : "Tap Tempo")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(AppTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1.2)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppTheme.accent.opacity(0.06))
                    )
            )
        }
        .buttonStyle(SCPressableButtonStyle(scale: 0.985, pressedOpacity: 0.97))
        .scaleEffect(tapScale)
    }
    
    private var keyPicker: some View {
        let majorKeys: [SongKey] = [.none, .c, .cSharp, .d, .dSharp, .e, .f, .fSharp, .g, .gSharp, .a, .aSharp, .b]
        let minorKeys: [SongKey] = [.cMinor, .dMinor, .eMinor, .fMinor, .gMinor, .aMinor, .bMinor]
        
        return VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(majorKeys) { key in
                        keyChip(key)
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(minorKeys) { key in
                        keyChip(key)
                    }
                }
            }
        }
    }
    
    private func keyChip(_ key: SongKey) -> some View {
        let isSelected = songKey == key
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { songKey = key }
        } label: {
            Text(key.label)
                .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .black : AppTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? AppTheme.accent : Color.white.opacity(0.05))
                )
        }
        .buttonStyle(SCPressableButtonStyle(scale: 0.985, pressedOpacity: 0.97))
    }
    
    private var countOffToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { countOffOnly.toggle() }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(countOffOnly ? AppTheme.accent : AppTheme.surfaceLight)
                        .frame(width: 42, height: 42)
                    Image(systemName: countOffOnly ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(countOffOnly ? .black : AppTheme.textMuted)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Count-off only")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(countOffOnly ? "Plays the count-in, then goes silent" : "Keeps the click running the whole song")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textMuted)
                }
                
                Spacer()
                
                ZStack {
                    Capsule()
                        .fill(countOffOnly ? AppTheme.accent : AppTheme.surfaceLight)
                        .frame(width: 50, height: 28)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        .offset(x: countOffOnly ? 10 : -10)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
            )
        }
        .buttonStyle(SCPressableButtonStyle(scale: 0.99, pressedOpacity: 0.97))
    }
    
    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Duration")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text(totalDuration == 0 ? "Manual stop" : "\(durationMinutes)m \(durationSecs)s")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(totalDuration == 0 ? AppTheme.textMuted : AppTheme.accent)
            }
            
            HStack(spacing: 14) {
                durationControl(title: "Minutes", value: $durationMinutes, range: 0...15)
                durationControl(title: "Seconds", value: $durationSecs, range: 0...59)
            }
            
            Text(totalDuration == 0 ? "Leave at 0:00 if you want live mode to run until you stop it." : "Auto-stops after \(durationMinutes)m \(durationSecs)s.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textMuted)
        }
    }
    
    private func durationControl(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
            
            HStack(spacing: 0) {
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 36, height: 42)
                }
                 .buttonStyle(SCPressableButtonStyle())
                
                Text("\(value.wrappedValue)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                
                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 36, height: 42)
                }
                 .buttonStyle(SCPressableButtonStyle())
            }
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    private func recordTap() {
        let now = Date()
        tapTimes.append(now)
        if tapTimes.count > 8 { tapTimes.removeFirst() }
        if tapTimes.count >= 2 {
            let last = tapTimes[tapTimes.count - 1]
            let prev = tapTimes[tapTimes.count - 2]
            if last.timeIntervalSince(prev) > 2.0 {
                tapTimes = [now]
                tapBPM = nil
                return
            }
        }
        if tapTimes.count >= 2 {
            let intervals = zip(tapTimes.dropFirst(), tapTimes).map { $0.timeIntervalSince($1) }
            let avg = intervals.reduce(0, +) / Double(intervals.count)
            let detected = Int((60.0 / avg).rounded())
            tapBPM = min(300, max(20, detected))
            if let tapBPM { bpm = tapBPM }
        }
    }
    
    private func save() {
        if let song {
            song.name = trimmedName
            song.bpm = bpm
            song.timeSignatureEnum = timeSignature
            song.subdivisionEnum = subdivision
            song.clickSoundEnum = clickSound
            song.countInBeats = countInBeats
            song.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            song.durationSeconds = totalDuration
            song.songKeyEnum = songKey
            song.countOffOnly = countOffOnly
        } else {
            let newSong = Song(
                name: trimmedName,
                bpm: bpm,
                timeSignature: timeSignature,
                subdivision: subdivision,
                clickSound: clickSound,
                countInBeats: countInBeats,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                durationSeconds: totalDuration,
                songKey: songKey,
                countOffOnly: countOffOnly
            )
            context.insert(newSong)
        }
        try? context.save()
        dismiss()
    }
}
