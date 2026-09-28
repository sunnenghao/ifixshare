import Foundation

struct Note: Identifiable, Codable {
    var id: String { uuid }
    var uuid: String = UUID().uuidString
    var ts: Double = Date().timeIntervalSince1970 * 1000
    var tag: String = "daily"          // daily / mood / book
    var text: String = ""
    var audio: String? = nil           // 本地文件名（audio/ 下）
    var dur: Double = 0                // 毫秒
    var trans: String? = nil           // 语音转写
    var updated: Double = Date().timeIntervalSince1970 * 1000
    var deleted: Int = 0
    var aremote: String? = nil         // 云端文件名

    enum CodingKeys: String, CodingKey {
        case uuid, ts, tag, text, audio, dur, trans, updated, deleted, aremote
    }

    init() {}

    init(from decoder: Decoder) {
        let c = try! decoder.container(keyedBy: CodingKeys.self)
        uuid = (try? c.decode(String.self, forKey: .uuid)) ?? UUID().uuidString
        ts = (try? c.decode(Double.self, forKey: .ts)) ?? Date().timeIntervalSince1970 * 1000
        tag = (try? c.decode(String.self, forKey: .tag)) ?? "daily"
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        audio = try? c.decode(String.self, forKey: .audio)
        dur = (try? c.decode(Double.self, forKey: .dur)) ?? 0
        trans = try? c.decode(String.self, forKey: .trans)
        updated = (try? c.decode(Double.self, forKey: .updated)) ?? ts
        deleted = (try? c.decode(Int.self, forKey: .deleted)) ?? 0
        aremote = try? c.decode(String.self, forKey: .aremote)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(uuid, forKey: .uuid); try c.encode(ts, forKey: .ts)
        try c.encode(tag, forKey: .tag); try c.encode(text, forKey: .text)
        try c.encodeIfPresent(audio, forKey: .audio); try c.encode(dur, forKey: .dur)
        try c.encodeIfPresent(trans, forKey: .trans); try c.encode(updated, forKey: .updated)
        try c.encode(deleted, forKey: .deleted); try c.encodeIfPresent(aremote, forKey: .aremote)
    }
}

struct Summary: Identifiable, Codable {
    var id: String = UUID().uuidString
    var month: String = ""
    var content: String = ""
    var created: Double = Date().timeIntervalSince1970 * 1000
}

final class Store: ObservableObject {
    static let shared = Store()
    @Published var notes: [Note] = []
    @Published var summaries: [Summary] = []

    private var dir: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    private var notesURL: URL { dir.appendingPathComponent("notes.json") }
    private var sumURL: URL { dir.appendingPathComponent("summaries.json") }
    var audioDir: URL { dir.appendingPathComponent("audio") }

    init() { load() }

    func load() {
        let fm = FileManager.default
        try? fm.createDirectory(at: audioDir, withIntermediateDirectories: true)
        if let d = try? Data(contentsOf: notesURL),
           let list = try? JSONDecoder().decode([Note].self, from: d) { notes = list }
        if let d = try? Data(contentsOf: sumURL),
           let list = try? JSONDecoder().decode([Summary].self, from: d) { summaries = list }
    }

    private func saveNotes() {
        if let d = try? JSONEncoder().encode(notes) { try? d.write(to: notesURL) }
    }
    private func saveSums() {
        if let d = try? JSONEncoder().encode(summaries) { try? d.write(to: sumURL) }
    }

    func save(_ n: Note) {
        if let i = notes.firstIndex(where: { $0.uuid == n.uuid }) {
            var m = n; m.updated = Date().timeIntervalSince1970 * 1000
            notes[i] = m
        } else { notes.append(n) }
        saveNotes()
    }

    func softDelete(_ n: Note) {
        if let i = notes.firstIndex(where: { $0.uuid == n.uuid }) {
            notes[i].deleted = 1
            notes[i].updated = Date().timeIntervalSince1970 * 1000
            saveNotes()
        }
    }

    func purge(_ uuid: String) {
        notes.removeAll { $0.uuid == uuid }
        saveNotes()
    }

    func visible(tag: String?) -> [Note] {
        notes.filter { $0.deleted == 0 && (tag == nil || $0.tag == tag) }
            .sorted { $0.ts > $1.ts }
    }

    func audioURL(_ name: String) -> URL { audioDir.appendingPathComponent(name) }

    func addSummary(_ s: Summary) { summaries.insert(s, at: 0); saveSums() }
    func deleteSummary(_ s: Summary) { summaries.removeAll { $0.id == s.id }; saveSums() }

    var nick: String {
        get { UserDefaults.standard.string(forKey: "nick") ?? "哽哽" }
        set { UserDefaults.standard.set(newValue, forKey: "nick") }
    }
}
