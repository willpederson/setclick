import Foundation
import SwiftData

// MARK: - Enums

enum Subdivision: String, CaseIterable, Codable, Identifiable, CustomStringConvertible {
    case quarter = "Quarter"
    case eighth = "Eighth"
    case triplet = "Triplet"
    var id: String { rawValue }
    var description: String { label }
    var clicksPerBeat: Int {
        switch self {
        case .quarter: return 1
        case .eighth: return 2
        case .triplet: return 3
        }
    }
    var label: String {
        switch self {
        case .quarter: return "1/4"
        case .eighth: return "1/8"
        case .triplet: return "1/8T"
        }
    }
}

enum TimeSignature: String, CaseIterable, Codable, Identifiable, CustomStringConvertible {
    case twoFour = "2/4"
    case threeFour = "3/4"
    case fourFour = "4/4"
    case fiveFour = "5/4"
    case sixEight = "6/8"
    case sevenEight = "7/8"
    var id: String { rawValue }
    var description: String { label }
    var numerator: Int {
        switch self {
        case .twoFour: return 2
        case .threeFour: return 3
        case .fourFour: return 4
        case .fiveFour: return 5
        case .sixEight: return 6
        case .sevenEight: return 7
        }
    }
    var label: String { rawValue }
}

enum ClickSound: String, CaseIterable, Codable, Identifiable, CustomStringConvertible {
    case classic = "Classic"
    case woodblock = "Woodblock"
    case beep = "Beep"
    case hihat = "Hi-Hat"
    var id: String { rawValue }
    var description: String { rawValue }
}

enum SongKey: String, CaseIterable, Codable, Identifiable {
    case none = "—"
    case c = "C"
    case cSharp = "C#"
    case d = "D"
    case dSharp = "Eb"
    case e = "E"
    case f = "F"
    case fSharp = "F#"
    case g = "G"
    case gSharp = "Ab"
    case a = "A"
    case aSharp = "Bb"
    case b = "B"
    case cMinor = "Cm"
    case dMinor = "Dm"
    case eMinor = "Em"
    case fMinor = "Fm"
    case gMinor = "Gm"
    case aMinor = "Am"
    case bMinor = "Bm"
    var id: String { rawValue }
    var label: String { rawValue }
}

// MARK: - Codable Section (for JSON storage in Song)

struct SongSection: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var name: String = ""
    var bars: Int = 8
}

// MARK: - SwiftData Models

@Model
final class Song {
    var name: String = ""
    var bpm: Int = 120
    var timeSignature: String = "4/4"
    var subdivision: String = "Quarter"
    var clickSound: String = "Classic"
    var countInBeats: Int = 4
    var notes: String = ""
    var durationSeconds: Int = 0
    var sectionsData: Data? = nil
    var createdAt: Date = Date()
    var songKey: String = "—"   // SongKey raw value
    var countOffOnly: Bool = false   // true = count-in then silence
    
    var timeSignatureEnum: TimeSignature {
        get { TimeSignature(rawValue: timeSignature) ?? .fourFour }
        set { timeSignature = newValue.rawValue }
    }
    var subdivisionEnum: Subdivision {
        get { Subdivision(rawValue: subdivision) ?? .quarter }
        set { subdivision = newValue.rawValue }
    }
    var clickSoundEnum: ClickSound {
        get { ClickSound(rawValue: clickSound) ?? .classic }
        set { clickSound = newValue.rawValue }
    }
    var songKeyEnum: SongKey {
        get { SongKey(rawValue: songKey) ?? .none }
        set { songKey = newValue.rawValue }
    }
    
    var sections: [SongSection] {
        get {
            guard let data = sectionsData else { return [] }
            return (try? JSONDecoder().decode([SongSection].self, from: data)) ?? []
        }
        set {
            sectionsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    var durationFormatted: String {
        guard durationSeconds > 0 else { return "" }
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
    
    init(name: String = "", bpm: Int = 120, timeSignature: TimeSignature = .fourFour, subdivision: Subdivision = .quarter, clickSound: ClickSound = .classic, countInBeats: Int = 4, notes: String = "", durationSeconds: Int = 0, songKey: SongKey = .none, countOffOnly: Bool = false) {
        self.name = name
        self.bpm = bpm
        self.timeSignature = timeSignature.rawValue
        self.subdivision = subdivision.rawValue
        self.clickSound = clickSound.rawValue
        self.countInBeats = countInBeats
        self.notes = notes
        self.durationSeconds = durationSeconds
        self.songKey = songKey.rawValue
        self.countOffOnly = countOffOnly
    }
}

@Model
final class SetlistEntry {
    var order: Int = 0
    var song: Song?
    var setlist: Setlist?
    
    init(order: Int = 0, song: Song? = nil, setlist: Setlist? = nil) {
        self.order = order
        self.song = song
        self.setlist = setlist
    }
}

@Model
final class Setlist {
    var name: String = ""
    @Relationship(deleteRule: .cascade, inverse: \SetlistEntry.setlist)
    var entries: [SetlistEntry] = []
    var createdAt: Date = Date()
    
    var sortedEntries: [SetlistEntry] {
        entries.filter { !$0.isDeleted }.sorted { $0.order < $1.order }
    }
    
    init(name: String = "") {
        self.name = name
    }
}

// MARK: - Sharing

struct ShareableSong: Codable, Sendable {
    var name: String
    var bpm: Int
    var timeSignature: String
    var subdivision: String
    var clickSound: String
    var countInBeats: Int
    var notes: String
    var durationSeconds: Int
    var sections: [SongSection]
    var songKey: String
    var countOffOnly: Bool
}

struct ShareableSetlist: Codable, Sendable {
    var name: String
    var songs: [ShareableSong]
}

struct AppBackup: Codable, Sendable {
    var exportedAt: Date
    var songs: [ShareableSong]
    var setlists: [ShareableSetlist]
}
