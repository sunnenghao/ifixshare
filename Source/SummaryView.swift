import SwiftUI

struct SummaryView: View {
    @ObservedObject var store = Store.shared
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())
    @State private var custom = ""
    @State private var busy = false
    @State private var result: (String, String)? = nil   // (标题, 内容)

    var body: some View {
        ZStack { C.cream.ignoresSafeArea() }
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(2020...2035, id: \.self) { y in
                        ForEach(1...12, id: \.self) { m in
                            Button("\(y)年\(m)月") { year = y; month = m }
                        }
                    }
                } label: {
                    Text("\(year)年\(month)月")
                        .foregroundColor(C.purpleDeep).font(.system(size: 14))
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.25), lineWidth: 1)))
                }
                Button { generate() } label: {
                    HStack { if busy { ProgressView().tint(.white).padding(.trailing, 4) }
                        Text("开始生成") }
                        .foregroundColor(.white).font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 24).fill(C.purple))
                }.disabled(busy)
            }.padding(.horizontal, 18)

            TextField("附加要求（可选）：比如“重点写我们吵架和好的部分”", text: $custom, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 13))
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.25), lineWidth: 1)))
                .padding(.horizontal, 18)

            Text("历史总结").font(.system(size: 13)).foregroundColor(C.textGray)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22)

            List {
                ForEach(store.summaries) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(title(s.month)).font(.system(size: 15, weight: .bold)).foregroundColor(C.purpleDeep)
                            Spacer()
                            Button { store.deleteSummary(s) } label: {
                                Image(systemName: "trash").foregroundColor(C.textGray)
                            }
                        }
                        Text(s.content).font(.system(size: 13)).foregroundColor(C.textDark)
                            .lineSpacing(3).lineLimit(5)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { result = (title(s.month), s.content) }
                    .listRowBackground(RoundedRectangle(cornerRadius: 14).fill(.white)
                        .shadow(color: .black.opacity(0.05), radius: 3, y: 1))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("AI 月度总结").navigationBarTitleDisplayMode(.inline)
        .alert(result?.0 ?? "", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
            if result != nil && !store.summaries.contains(where: { $0.content == result!.1 }) {
                Button("保存") {
                    var s = Summary(); s.month = "\(year)-\(String(format: "%02d", month))"; s.content = result!.1
                    store.addSummary(s)
                }
            }
            Button("关闭", role: .cancel) {}
        } message: { Text(result?.1 ?? "") }
    }

    func title(_ m: String) -> String {
        let ps = m.split(separator: "-")
        guard ps.count == 2, let y = Int(ps[0]), let mo = Int(ps[1]) else { return m }
        return "\(y)年\(mo)月"
    }

    func generate() {
        let cal = Calendar.current
        let comps = DateComponents(year: year, month: month)
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: .month, value: 1, to: start) else { return }
        let list = store.notes.filter { $0.deleted == 0 && $0.ts >= start.timeIntervalSince1970 * 1000 && $0.ts < end.timeIntervalSince1970 * 1000 }
        if list.isEmpty { result = ("这个月还没有记录哦", "先记几笔再来总结吧"); return }
        busy = true
        let df = DateFormatter(); df.dateFormat = "MM-dd"
        var body = ""
        for n in list {
            body += "[\(df.string(from: Date(timeIntervalSince1970: n.ts / 1000))) \(n.tag == "mood" ? "情绪" : n.tag == "book" ? "小本本" : "日常")] "
            if !n.text.isEmpty { body += String(n.text.prefix(300)) }
            if let t = n.trans, !t.isEmpty { body += "（语音转写：\(t.prefix(300))）" }
            else if n.audio != nil { body += "（有一段 \(Int(n.dur / 1000)) 秒的语音）" }
            body += "\n"
        }
        let sys = "你是一对情侣的私人 AI 记录助手。语气温暖亲昵，像共同的朋友。全程用简体中文。总结要具体，引用记录里的真实细节，不要空话。"
        let user = "以下是我们 \(year)年\(month)月 的相处记录。\n" +
            "请写一份月度总结，包含四个部分：\n1️⃣ 本月基调（一句话）\n2️⃣ 甜蜜瞬间（列举 2-4 个）\n3️⃣ 小摩擦与反思（如有）\n4️⃣ 下月小建议（2-3 条，具体可行）\n" +
            (custom.isEmpty ? "" : "用户的附加要求：\(custom)\n") + "\n记录如下：\n" + String(body.prefix(6000))
        Task {
            do {
                let r = try await Llm.chat(system: sys, user: user)
                await MainActor.run { busy = false; result = ("\(year)年\(month)月 · 秘语总结", r) }
            } catch {
                await MainActor.run { busy = false; result = ("生成失败", error.localizedDescription) }
            }
        }
    }
}
