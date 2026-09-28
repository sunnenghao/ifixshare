import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store = Store.shared

    @State private var nick = ""
    @State private var aiBase = ""
    @State private var aiKey = ""
    @State private var aiModel = ""
    @State private var aiAsr = ""
    @State private var davUrl = "https://dav.jianguoyun.com/dav/"
    @State private var davUser = ""
    @State private var davPass = ""
    @State private var syncing = false
    @State private var alert: (String, String)? = nil

    var body: some View {
        ZStack { C.cream.ignoresSafeArea() }
        Form {
            Section("TA 的昵称（标题会用到）") {
                TextField("比如：哽哽", text: $nick)
            }
            Section("AI 接口（OpenAI 兼容格式）") {
                TextField("如 https://api.deepseek.com/v1", text: $aiBase)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                SecureField("API Key（sk-…）", text: $aiKey)
                TextField("对话模型，如 deepseek-chat / glm-4-flash", text: $aiModel)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                TextField("语音转写模型（如 whisper-1，留空不转写）", text: $aiAsr)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                Button("测试连接") { testAI() }
            }
            Section("两台手机同步（坚果云 WebDAV）") {
                TextField("服务器地址（默认坚果云）", text: $davUrl)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                TextField("坚果云账号（注册邮箱）", text: $davUser)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                SecureField("应用密码（不是登录密码！）", text: $davPass)
                Button { syncNow() } label: {
                    HStack { if syncing { ProgressView().padding(.trailing, 4) }
                        Text("⇅ 立即同步") }
                }.disabled(syncing)
                Text("两台手机填同一个坚果云账号和同一个应用密码（网页版「账户信息-安全选项-应用密码」里生成），即可互相同步记录和语音。")
                    .font(.system(size: 12)).foregroundColor(C.textGray)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            nick = store.nick
            aiBase = Llm.base; aiKey = Llm.key; aiModel = Llm.model; aiAsr = Llm.asr
            let d = UserDefaults.standard
            davUrl = d.string(forKey: "davUrl") ?? davUrl
            davUser = d.string(forKey: "davUser") ?? ""
            davPass = d.string(forKey: "davPass") ?? ""
        }
        .onDisappear { persist() }
        .alert(alert?.0 ?? "", isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })) {
            Button("好的", role: .cancel) {}
        } message: { Text(alert?.1 ?? "") }
    }

    func persist() {
        store.nick = nick.isEmpty ? "哽哽" : nick
        let d = UserDefaults.standard
        d.set(aiBase.trimmingCharacters(in: .whitespaces), forKey: "aiBase")
        d.set(aiKey.trimmingCharacters(in: .whitespaces), forKey: "aiKey")
        d.set(aiModel.trimmingCharacters(in: .whitespaces), forKey: "aiModel")
        d.set(aiAsr.trimmingCharacters(in: .whitespaces), forKey: "aiAsr")
        d.set(davUrl.trimmingCharacters(in: .whitespaces), forKey: "davUrl")
        d.set(davUser.trimmingCharacters(in: .whitespaces), forKey: "davUser")
        d.set(davPass, forKey: "davPass")
    }

    func testAI() {
        persist()
        Task {
            do {
                let r = try await Llm.chat(system: "你是连通性测试助手。", user: "请只回复两个字：成功")
                await MainActor.run { alert = ("连接成功", "模型回复：\(r)") }
            } catch {
                await MainActor.run { alert = ("连接失败", error.localizedDescription) }
            }
        }
    }

    func syncNow() {
        persist()
        syncing = true
        Task {
            do {
                let msg = try await SyncEngine.sync()
                await MainActor.run { syncing = false; alert = ("同步完成", msg) }
            } catch {
                await MainActor.run { syncing = false; alert = ("同步失败", error.localizedDescription) }
            }
        }
    }
}
