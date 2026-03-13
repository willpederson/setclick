import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: data)
    }
}

struct SetlistsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Setlist.createdAt, order: .reverse) private var setlists: [Setlist]
    @Query(sort: \Song.name) private var songs: [Song]
    @State private var showAddSetlist = false
    @State private var showPlusMenu = false
    @State private var newSetlistName = ""
    @State private var selectedSetlist: Setlist?
    @State private var showExportBackup = false
    @State private var showImportBackup = false
    @State private var importError: String?
        @State private var setlistForActions: Setlist?
    @State private var showSetlistActions = false
    @State private var exportDocument: BackupDocument?
    @State private var exportFilename = "SetClick Backup"
    @State private var deleteTarget: Setlist?
    
    
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            mainList
            
            if showSetlistActions, let setlist = setlistForActions {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.18)) {
                            showSetlistActions = false
                            setlistForActions = nil
                        }
                    }
                
                setlistActionSheet(setlist)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
            }
            
            if showPlusMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showPlusMenu = false
                        }
                    }
                
                VStack(alignment: .leading, spacing: 6) {
                    plusMenuButton("New Setlist", icon: "plus") {
                        showPlusMenu = false
                        showAddSetlist = true
                    }
                    plusMenuButton("Import Setlist", icon: "square.and.arrow.down") {
                        showPlusMenu = false
                        showImportBackup = true
                    }
                }
                .padding(8)
                .frame(width: 200)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(AppTheme.surface.opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 16, y: 10)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 70)
                .padding(.trailing, 20)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .zIndex(30)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: showSetlistActions)
        .fullScreenCover(item: $selectedSetlist) { setlist in
            SetlistDetailView(setlist: setlist, onBack: { selectedSetlist = nil })
        }
        .alert("New Setlist", isPresented: $showAddSetlist) {
            TextField("Setlist name", text: $newSetlistName)
            Button("Cancel", role: .cancel) { newSetlistName = "" }
            Button("Create") {
                let name = newSetlistName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    context.insert(Setlist(name: name))
                }
                newSetlistName = ""
            }
        }
        .alert("Backup Error", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .alert("Delete Setlist?", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Delete", role: .destructive) {
                if let deleteTarget {
                    context.delete(deleteTarget)
                }
                self.deleteTarget = nil
            }
        } message: {
            Text("This will permanently delete the selected setlist.")
        }

        .fileExporter(
            isPresented: $showExportBackup,
            document: exportDocument ?? BackupDocument(data: Data()),
            contentType: .json,
            defaultFilename: exportFilename
        ) { _ in
            exportDocument = nil
            exportFilename = "SetClick Backup"
        }
        .fileImporter(
            isPresented: $showImportBackup,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }
    
    private var mainList: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Setlists")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Built for fast gig prep and stage-ready recall")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            showPlusMenu = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 40, height: 40)
                            .glassCircleButton()
                    }
                    .buttonStyle(SCPressableButtonStyle())
                }
                
                if !setlists.isEmpty {
                    HStack(spacing: 10) {
                        metricPill(title: "\(setlists.count)", subtitle: "setlists")
                        metricPill(title: "\(songs.count)", subtitle: "songs")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            if setlists.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(setlists) { setlist in
                            setlistRow(setlist)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 90)
                }
            }
        }
    }
    
    private func plusMenuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.12)) { action() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.035))
            )
        }
        .buttonStyle(SCPressableButtonStyle())
    }
    
    private func setlistActionSheet(_ setlist: Setlist) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 8) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(setlist.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("\(safeSongCount(setlist)) songs")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            showSetlistActions = false
                            setlistForActions = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.textMuted)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(SCPressableButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                // Actions
                sheetAction("Open", icon: "arrow.right.circle", color: AppTheme.accent) {
                    showSetlistActions = false
                    setlistForActions = nil
                    selectedSetlist = setlist
                }
                sheetAction("Export", icon: "square.and.arrow.up", color: AppTheme.accent) {
                    showSetlistActions = false
                    setlistForActions = nil
                    exportSingleSetlist(setlist)
                }
                sheetAction("Duplicate", icon: "plus.square.on.square", color: AppTheme.accent) {
                    showSetlistActions = false
                    setlistForActions = nil
                    duplicate(setlist)
                }
                
                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                
                sheetAction("Delete Setlist", icon: "trash", color: AppTheme.destructive) {
                    showSetlistActions = false
                    setlistForActions = nil
                    deleteTarget = setlist
                }
                
                Spacer().frame(height: 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 30, y: -10)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
    
    private func sheetAction(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { action() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color == AppTheme.destructive ? color : AppTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
            )
            .padding(.horizontal, 12)
        }
        .buttonStyle(SCPressableButtonStyle())
    }
    
        private var validSongIDs: Set<PersistentIdentifier> {
        Set(songs.map { $0.persistentModelID })
    }
    
    private func safeSongCount(_ setlist: Setlist) -> Int {
        setlist.sortedEntries.filter { entry in
            guard let song = entry.song else { return false }
            return validSongIDs.contains(song.persistentModelID)
        }.count
    }
    
    private func safeDuration(_ setlist: Setlist) -> Int {
        setlist.sortedEntries.compactMap { entry -> Int? in
            guard let song = entry.song, validSongIDs.contains(song.persistentModelID) else { return nil }
            return song.durationSeconds
        }.reduce(0, +)
    }
    
    private func setlistRow(_ setlist: Setlist) -> some View {
        let totalDuration = safeDuration(setlist)
        return HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "music.note.list")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(setlist.name)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    infoPill(text: "\(safeSongCount(setlist)) songs")
                    if totalDuration > 0 {
                        infoPill(text: formatDuration(totalDuration))
                    }
                }
            }
            
            Spacer()
            
            Button {
                setlistForActions = setlist
                showSetlistActions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.05))
                    )
            }
            .buttonStyle(SCPressableButtonStyle())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.surfaceLight.opacity(0.55), AppTheme.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 10, y: 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            withAnimation { selectedSetlist = setlist }
        }
        .contextMenu {
            Button {
                exportSingleSetlist(setlist)
            } label: {
                Label("Export This Setlist", systemImage: "square.and.arrow.up")
            }
            Button {
                duplicate(setlist)
            } label: {
                Label("Duplicate Setlist", systemImage: "plus.square.on.square")
            }
            
            Button(role: .destructive) {
                deleteTarget = setlist
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func metricPill(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            Text(subtitle.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.1)
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                )
        )
    }
    
    private func infoPill(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(AppTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
            )
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes >= 60 {
            return String(format: "%dh %02dm", minutes / 60, minutes % 60)
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
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
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 36))
                    .foregroundColor(AppTheme.accent)
            }
            Text("No setlists yet")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
            Text("Create a setlist to organize songs for a gig")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
            SCPrimaryButton(title: "New Setlist", icon: "plus") {
                showAddSetlist = true
            }
            .frame(width: 200)
            .padding(.top, 8)
            
            Button {
                showImportBackup = true
            } label: {
                Text("Import Backup")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
            .buttonStyle(SCPressableButtonStyle())
        }
    }
    
    private func encodeBackup(_ backup: AppBackup) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(backup)) ?? Data()
    }
    
    private func duplicate(_ setlist: Setlist) {
        let copy = Setlist(name: "\(setlist.name) Copy")
        context.insert(copy)
        for (index, entry) in setlist.sortedEntries.enumerated() {
            guard let song = entry.song else { continue }
            let newEntry = SetlistEntry(order: index, song: song, setlist: copy)
            context.insert(newEntry)
        }
        try? context.save()
    }
    
    private func exportSingleSetlist(_ setlist: Setlist) {
        exportDocument = BackupDocument(data: encodeBackup(buildBackup(for: setlist)))
        exportFilename = setlist.name.isEmpty ? "Setlist Export" : "\(setlist.name)"
        showExportBackup = true
    }
    
    private func buildBackup() -> AppBackup {
        AppBackup(
            exportedAt: Date(),
            songs: songs.filter { validSongIDs.contains($0.persistentModelID) }.map { shareableSong(from: $0) },
            setlists: setlists.map { buildShareableSetlist(from: $0) }
        )
    }
    
    private func buildBackup(for setlist: Setlist) -> AppBackup {
        let usedSongs = setlist.sortedEntries.compactMap { $0.song }.filter { validSongIDs.contains($0.persistentModelID) }
        return AppBackup(
            exportedAt: Date(),
            songs: usedSongs.map { shareableSong(from: $0) },
            setlists: [buildShareableSetlist(from: setlist)]
        )
    }
    
    private func buildShareableSetlist(from setlist: Setlist) -> ShareableSetlist {
        ShareableSetlist(
            name: setlist.name,
            songs: setlist.sortedEntries.compactMap { entry in
                guard let song = entry.song, validSongIDs.contains(song.persistentModelID) else { return nil }
                return shareableSong(from: song)
            }
        )
    }
    
    private func shareableSong(from song: Song) -> ShareableSong {
        ShareableSong(
            name: song.name,
            bpm: song.bpm,
            timeSignature: song.timeSignature,
            subdivision: song.subdivision,
            clickSound: song.clickSound,
            countInBeats: song.countInBeats,
            notes: song.notes,
            durationSeconds: song.durationSeconds,
            sections: song.sections,
            songKey: song.songKey,
            countOffOnly: song.countOffOnly
        )
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backup = try decoder.decode(AppBackup.self, from: data)
            importBackup(backup)
        } catch {
            importError = error.localizedDescription
        }
    }
    
    private func importBackup(_ backup: AppBackup) {
        var songMap: [String: Song] = [:]
        
        for songData in backup.songs {
            let key = songIdentityKey(songData)
            if let existing = songs.first(where: { songIdentityKey($0) == key }) {
                songMap[key] = existing
                continue
            }
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
            songMap[key] = song
        }
        
        for setlistData in backup.setlists {
            let newSetlist = Setlist(name: setlistData.name)
            context.insert(newSetlist)
            for (index, songData) in setlistData.songs.enumerated() {
                let key = songIdentityKey(songData)
                guard let song = songMap[key] ?? songs.first(where: { songIdentityKey($0) == key }) else { continue }
                let entry = SetlistEntry(order: index, song: song, setlist: newSetlist)
                context.insert(entry)
            }
        }
        
        try? context.save()
    }
    
    private func songIdentityKey(_ song: ShareableSong) -> String {
        [song.name.lowercased(), String(song.bpm), song.timeSignature, song.songKey].joined(separator: "|")
    }
    
    private func songIdentityKey(_ song: Song) -> String {
        [song.name.lowercased(), String(song.bpm), song.timeSignature, song.songKey].joined(separator: "|")
    }
}
