import Foundation

struct DavCfg {
    var base: String   // 如 https://dav.jianguoyun.com/dav/
    var user: String
    var pass: String
}

enum WebDav {
    static func cfg() -> DavCfg? {
        let d = UserDefaults.standard
        let url = d.string(forKey: "davUrl") ?? "https://dav.jianguoyun.com/dav/"
        let user = d.string(forKey: "davUser") ?? ""
        let pass = d.string(forKey: "davPass") ?? ""
        if url.isEmpty || user.isEmpty || pass.isEmpty { return nil }
        return DavCfg(base: url.hasSuffix("/") ? url : url + "/", user: user, pass: pass)
    }

    static func request(_ c: DavCfg, _ method: String, _ path: String, body: Data? = nil, headers: [String: String] = [:]) async throws -> (Int, Data?) {
        var req = URLRequest(url: URL(string: c.base + path)!)
        req.httpMethod = method
        req.timeoutInterval = 60
        let token = Data("\(c.user):\(c.pass)".utf8).base64EncodedString()
        req.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        if let b = body {
            req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            req.httpBody = b
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        return ((resp as? HTTPURLResponse)?.statusCode ?? 0, data)
    }

    static func ensureDir(_ c: DavCfg, _ path: String) async throws {
        let (code, _) = try await request(c, "MKCOL", path)
        if !(200...299).contains(code) && code != 405 {
            throw NSError(domain: "dav", code: code,
                userInfo: [NSLocalizedDescriptionKey: "创建目录失败 HTTP \(code)，请检查账号和应用密码"])
        }
    }

    static func put(_ c: DavCfg, _ path: String, _ data: Data) async throws {
        let (code, _) = try await request(c, "PUT", path, body: data)
        if !(200...299).contains(code) { throw NSError(domain: "dav", code: code,
            userInfo: [NSLocalizedDescriptionKey: "上传失败 HTTP \(code)"]) }
    }

    static func get(_ c: DavCfg, _ path: String) async throws -> Data? {
        let (code, data) = try await request(c, "GET", path)
        if code == 404 { return nil }
        if !(200...299).contains(code) { throw NSError(domain: "dav", code: code,
            userInfo: [NSLocalizedDescriptionKey: "下载失败 HTTP \(code)"]) }
        return data
    }
}

enum SyncEngine {
    static func sync() async throws -> String {
        guard let cfg = WebDav.cfg() else {
            throw NSError(domain: "dav", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "还没配置坚果云 WebDAV"])
        }
        let store = Store.shared
        try await WebDav.ensureDir(cfg, "miyu")
        try await WebDav.ensureDir(cfg, "miyu/audio")

        var remote: [[String: Any]] = []
        if let raw = try await WebDav.get(cfg, "miyu/notes.json"),
           let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
           let arr = obj["notes"] as? [[String: Any]] { remote = arr }
        func rBy(_ uuid: String) -> [String: Any]? { remote.first { $0["uuid"] as? String == uuid } }

        var up = 0, down = 0

        // 本地 -> 云端
        for n in store.notes {
            var n = n
            let r = rBy(n.uuid)
            let rUpd = r?["updated"] as? Double ?? 0
            if r == nil || n.updated > rUpd {
                if let localAudio = n.audio, n.aremote == nil,
                   FileManager.default.fileExists(atPath: store.audioURL(localAudio).path) {
                    let fname = "\(n.uuid).m4a"
                    let data = try Data(contentsOf: store.audioURL(localAudio))
                    try await WebDav.put(cfg, "miyu/audio/\(fname)", data)
                    n.aremote = fname
                }
                let rec: [String: Any] = [
                    "uuid": n.uuid, "ts": n.ts, "tag": n.tag, "text": n.text,
                    "dur": n.dur, "trans": n.trans ?? "", "deleted": n.deleted,
                    "updated": n.updated, "aremote": n.aremote ?? ""
                ]
                if let i = remote.firstIndex(where: { $0["uuid"] as? String == n.uuid }) { remote[i] = rec } else { remote.append(rec) }
                store.save(n)
                up += 1
            }
        }

        // 云端 -> 本地
        for r in remote {
            guard let uuid = r["uuid"] as? String, !uuid.isEmpty else { continue }
            let local = store.notes.first { $0.uuid == uuid }
            if (r["deleted"] as? Int ?? 0) == 1 {
                if local != nil { store.purge(uuid) }
                continue
            }
            let rUpd = r["updated"] as? Double ?? 0
            if local == nil {
                var n = Note()
                n.uuid = uuid
                n.ts = r["ts"] as? Double ?? 0
                n.tag = r["tag"] as? String ?? "daily"
                n.text = r["text"] as? String ?? ""
                n.dur = r["dur"] as? Double ?? 0
                let tr = r["trans"] as? String ?? ""
                n.trans = tr.isEmpty ? nil : tr
                n.updated = rUpd
                let fname = r["aremote"] as? String ?? ""
                if !fname.isEmpty {
                    let url = store.audioURL(fname)
                    if !FileManager.default.fileExists(atPath: url.path),
                       let data = try await WebDav.get(cfg, "miyu/audio/\(fname)") {
                        try? data.write(to: url)
                    }
                    n.audio = fname; n.aremote = fname
                }
                store.notes.append(n); store.save(n); down += 1
            } else if rUpd > local!.updated {
                var n = local!
                n.ts = r["ts"] as? Double ?? n.ts
                n.tag = r["tag"] as? String ?? n.tag
                n.text = r["text"] as? String ?? n.text
                n.dur = r["dur"] as? Double ?? n.dur
                let tr = r["trans"] as? String ?? ""
                n.trans = tr.isEmpty ? nil : tr
                n.updated = rUpd
                let fname = r["aremote"] as? String ?? ""
                if !fname.isEmpty && fname != n.aremote {
                    let url = store.audioURL(fname)
                    if !FileManager.default.fileExists(atPath: url.path),
                       let data = try await WebDav.get(cfg, "miyu/audio/\(fname)") {
                        try? data.write(to: url)
                    }
                    n.audio = fname; n.aremote = fname
                }
                store.save(n); down += 1
            }
        }

        // 保存远端索引
        let idx = try JSONSerialization.data(
            withJSONObject: ["notes": remote], options: [.prettyPrinted])
        try await WebDav.put(cfg, "miyu/notes.json", idx)
        return "同步完成：上传 \(up) 条，下载 \(down) 条"
    }
}
