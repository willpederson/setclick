import SwiftUI
import SwiftData

struct SetlistDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Song.name) private var allSongs: [Song]
    @Bindable var setlist: Setlist
    var onBack: (() -> Void)? = nil
    @State private var showAddSongs = false
    @State private var showLiveMode = false
    @State private var isEditing = false
    
    private var validSongIDs: Set<PersistentIdentifier> {
        Set(allSongs.map { $0.persistentModelID })
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                
                if setlist.sortedEntries.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(setlist.sortedEntries) { entry in
                                if let song = entry.song, validSongIDs.contains(song.persistentModelID) {
                                    setlistRow(entry: entry, song: song, order: entry.order)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    }
                    
                    SCPrimaryButton(title: "LIVE MODE", icon: "play.fill") {
                        showLiveMode = true
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 90)
                }
            }
        }
        .sheet(isPresented: $showAddSongs) {
            AddSongsToSetlistView(setlist: setlist)
        }
        .fullScreenCover(isPresented: $showLiveMode) {
            LiveModeView(setlist: setlist)
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                if let onBack {
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                HStack(spacing: 16) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isEditing.toggle() }
                    } label: {
                        Text(isEditing ? "Done" : "Edit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                    
                    Button { showAddSongs = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 32, height: 32)
                            .glassCircleButton()
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Text(setlist.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("\(setlist.entries.count) song\(setlist.entries.count == 1 ? "" : "s")")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private func setlistRow(entry: SetlistEntry, song: Song, order: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.accent.opacity(0.10))
                    .frame(width: 42, height: 42)
                Text("\(order + 1)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.accent)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(song.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    detailPill(song.timeSignature)
                    if song.songKeyEnum != .none {
                        detailPill(song.songKeyEnum.label)
                    }
                    if song.durationSeconds > 0 {
                        detailPill(song.durationFormatted)
                    }
                    if song.countOffOnly {
                        detailPill("Count-off")
                    }
                }
            }
            
            Spacer()
            
            if isEditing {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            moveEntry(entry, direction: -1)
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(entry.order == 0 ? AppTheme.textMuted : AppTheme.accent)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(SCPressableButtonStyle())
                    .disabled(entry.order == 0)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            moveEntry(entry, direction: 1)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(entry.order == setlist.sortedEntries.count - 1 ? AppTheme.textMuted : AppTheme.accent)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(SCPressableButtonStyle())
                    .disabled(entry.order == setlist.sortedEntries.count - 1)

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            context.delete(entry)
                            reorderEntries()
                            try? context.save()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.destructive)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(AppTheme.destructive.opacity(0.12)))
                    }
                    .buttonStyle(SCPressableButtonStyle())
                }
            } else {
                Text("\(song.bpm)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.surfaceLight.opacity(0.45), AppTheme.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                )
        )
    }
    
    private func detailPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(AppTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.05)))
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "music.note.list")
                    .font(.system(size: 36))
                    .foregroundColor(AppTheme.accent)
            }
            Text("No songs in this setlist")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
            SCPrimaryButton(title: "Add Songs", icon: "plus") {
                showAddSongs = true
            }
            .frame(width: 200)
        }
    }
    
    private func moveEntries(from source: IndexSet, to destination: Int) {
        var sorted = setlist.sortedEntries
        sorted.move(fromOffsets: source, toOffset: destination)
        for (i, entry) in sorted.enumerated() {
            entry.order = i
        }
    }

    private func reorderEntries() {
        for (i, entry) in setlist.sortedEntries.enumerated() {
            entry.order = i
        }
        try? context.save()
    }

    private func moveEntry(_ entry: SetlistEntry, direction: Int) {
        var sorted = setlist.sortedEntries
        guard let currentIndex = sorted.firstIndex(where: { $0.persistentModelID == entry.persistentModelID }) else { return }
        let newIndex = currentIndex + direction
        guard sorted.indices.contains(newIndex) else { return }
        sorted.swapAt(currentIndex, newIndex)
        for (i, item) in sorted.enumerated() {
            item.order = i
        }
        try? context.save()
    }
}

// MARK: - Add Songs Sheet

struct AddSongsToSetlistView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Song.name) private var allSongs: [Song]
    let setlist: Setlist
    @State private var selected: Set<PersistentIdentifier> = []
    @State private var searchText = ""
    
    private var availableSongs: [Song] {
        let existingIDs = Set(setlist.entries.compactMap { $0.song?.persistentModelID })
        return allSongs.filter { !existingIDs.contains($0.persistentModelID) }
    }

    private var filteredSongs: [Song] {
        let base = availableSongs
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text("Add Songs")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Button {
                        addSelected()
                        dismiss()
                    } label: {
                        Text("Add\(selected.count > 0 ? " (\(selected.count))" : "")")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(selected.isEmpty ? AppTheme.textMuted : AppTheme.accent)
                    }
                    .disabled(selected.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                if availableSongs.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("No songs available")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Add songs in the Songs tab first")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()
                } else {
                    SCTextField(placeholder: "Search songs", text: $searchText)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredSongs) { song in
                                let isSelected = selected.contains(song.persistentModelID)
                                Button {
                                    if isSelected {
                                        selected.remove(song.persistentModelID)
                                    } else {
                                        selected.insert(song.persistentModelID)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .stroke(isSelected ? AppTheme.accent : AppTheme.surfaceLight, lineWidth: 2)
                                                .frame(width: 26, height: 26)
                                            if isSelected {
                                                Circle()
                                                    .fill(AppTheme.accent)
                                                    .frame(width: 26, height: 26)
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.black)
                                            }
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(song.name)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(AppTheme.textPrimary)
                                            Text("\(song.bpm) BPM · \(song.timeSignature)")
                                                .font(.system(size: 13))
                                                .foregroundColor(AppTheme.textMuted)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(isSelected ? AppTheme.accent.opacity(0.06) : AppTheme.surface)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
    
    private func addSelected() {
        let currentMax = setlist.entries.map { $0.order }.max() ?? -1
        var order = currentMax + 1
        for song in availableSongs where selected.contains(song.persistentModelID) {
            let entry = SetlistEntry(order: order, song: song, setlist: setlist)
            context.insert(entry)
            order += 1
        }
    }
}
