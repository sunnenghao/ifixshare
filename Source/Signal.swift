import Foundation
import UIKit
import AudioToolbox

/// 实时互动信号：画板涂鸦 / 想你了。与安卓版共用同一个 WebDAV 信号箱协议。
enum Signal {
    struct Msg {
        var type: String
        var from: String
        var imgB64: String?
        var created: Double
        var file: String
    }

    static func deviceId() -> String {
        let d = UserDefaults.standard
        if let id = d.string(forKey: "deviceId"), !id.isEmpty { return id }
        let id = "\(UIDevice.current.model.prefix(6))-\(UUID().uuidString.prefix(8))"
        d.set(id, forKey: "deviceId")
        return id
    }

    static func send(_ type: String, imgB64: String? = nil) async throws {
        guard let cfg = WebDav.cfg() else {
            throw NSError(domain: "dav", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "还没配置坚果云同步"])
        }
        try await WebDav.ensureDir(cfg, "miyu")
        try await WebDav.ensureDir(cfg, "miyu/signal")
        let safe = deviceId().replacingOccurrences(of: "[^A-Za-z0-9-]", with: "", options: .regularExpression)
        let name = "sig_\(Int(Date().timeIntervalSince1970 * 1000))_\(safe).json"
        let jo: [String: Any] = [
            "type": type, "from": deviceId(), "img": imgB64 ?? "",
            "created": Date().timeIntervalSince1970 * 1000
        ]
        try await WebDav.put(cfg, "miyu/signal/\(name)", try JSONSerialization.data(withJSONObject: jo))
    }

    static func poll() async -> [Msg] {
        guard let cfg = WebDav.cfg() else { return [] }
        let me = deviceId().replacingOccurrences(of: "[^A-Za-z0-9-]", with: "", options: .regularExpression)
        do { try await WebDav.ensureDir(cfg, "miyu/signal") } catch { return [] }
        guard let (code, body) = try? await WebDav.request(cfg, "PROPFIND", "miyu/signal/", headers: ["Depth": "1"]),
              (200...299).contains(code), let data = body,
              let xml = String(data: data, encoding: .utf8) else { return [] }
        var names: [String] = []
        if let regex = try? NSRegularExpression(pattern: "sig_[A-Za-z0-9_.\\-]+\\.json") {
            let whole = NSRange(xml.startIndex..<xml.endIndex, in: xml)
            for m in regex.matches(in: xml, range: whole) {
                if let r = Range(m.range, in: xml) {
                    let n = String(xml[r])
                    if !names.contains(n) { names.append(n) }
                }
            }
        }
        var out: [Msg] = []
        for name in names {
            if name.contains(me) { continue }
            guard let raw = try? await WebDav.get(cfg, "miyu/signal/\(name)"),
                  let jo = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else { continue }
            let created = jo["created"] as? Double ?? 0
            if Date().timeIntervalSince1970 * 1000 - created > 6 * 3600 * 1000 {
                _ = try? await WebDav.request(cfg, "DELETE", "miyu/signal/\(name)")
                continue
            }
            out.append(Msg(
                type: jo["type"] as? String ?? "",
                from: jo["from"] as? String ?? "",
                imgB64: (jo["img"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                created: created, file: name))
        }
        return out
    }

    static func consume(_ m: Msg) {
        Task {
            guard let cfg = WebDav.cfg() else { return }
            _ = try? await WebDav.request(cfg, "DELETE", "miyu/signal/\(m.file)")
        }
    }

    static func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
}
