import Foundation

enum Llm {
    static var base: String { UserDefaults.standard.string(forKey: "aiBase") ?? "" }
    static var key: String { UserDefaults.standard.string(forKey: "aiKey") ?? "" }
    static var model: String { UserDefaults.standard.string(forKey: "aiModel") ?? "" }
    static var asr: String { UserDefaults.standard.string(forKey: "aiAsr") ?? "" }
    static var ready: Bool { !base.isEmpty && !key.isEmpty && !model.isEmpty }

    static func chat(system: String, user: String) async throws -> String {
        guard ready else {
            throw NSError(domain: "ai", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "请先到设置里配置 AI 接口"])
        }
        var req = URLRequest(url: URL(string: base.trimmingCharacters(in: .whitespaces).hasSuffix("/")
            ? base + "chat/completions" : base + "/chat/completions")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(code) else {
            throw NSError(domain: "ai", code: code,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)：\(String(data: data.prefix(300), encoding: .utf8) ?? "")"])
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let choices = obj["choices"] as? [[String: Any]] ?? []
        let msg = choices.first?["message"] as? [String: Any] ?? [:]
        return msg["content"] as? String ?? ""
    }

    static func transcribe(fileURL: URL) async throws -> String {
        guard !asr.isEmpty else {
            throw NSError(domain: "ai", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "未配置语音转写模型"])
        }
        var req = URLRequest(url: URL(string: base.trimmingCharacters(in: .whitespaces).hasSuffix("/")
            ? base + "audio/transcriptions" : base + "/audio/transcriptions")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 180
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let boundary = "----miyu\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\n\(asr)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"voice.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(code) else {
            throw NSError(domain: "ai", code: code,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)：\(String(data: data.prefix(300), encoding: .utf8) ?? "")"])
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return obj["text"] as? String ?? ""
    }
}
