import SwiftUI

struct MainView: View {
    @StateObject private var store = Store.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var filter: String? = nil
    @State private var question = ""
    @State private var syncing = false
    @State private var syncMsg: String? = nil
    @State private var showDoodle = false
    @State private var doodleImg: UIImage? = nil
    @State private var missAlert = false
    private var pollTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    @State private var handled: Set<String> = []

    private let bank = [
        "你接受突然拥抱，还是先问过意见？",
        "第一次见我时，你心里在想什么？",
        "如果我们吵架了，你希望谁先低头？",
        "你最喜欢我身上的哪个习惯？",
        "下个周末，最想和我一起做什么？",
        "有没有一句我一直没说出口的话，你其实在等？",
        "如果给我们的关系换一首主题曲，你会选哪首？",
        "哪一顿饭让你到现在还惦记？",
        "你最想要的小名是什么？我以后就这么叫你。",
        "说一个只有你知道、还没告诉过我的小秘密吧。"
    ]

    var body: some View {
        NavigationStack {
            ZStack { C.cream.ignoresSafeArea() }
            VStack(spacing: 0) {
            HStack {
                Text("秘语").font(.system(size: 19, weight: .bold)).foregroundColor(C.textDark)
                Spacer()
                Button { syncNow() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(C.textDark)
                }.padding(.trailing, 12).disabled(syncing)
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "gearshape").foregroundColor(C.textDark)
                }
            }.padding(.horizontal, 18).frame(height: 52)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("全部", key: nil)
                    chip("☀ 日常", key: "daily")
                    chip("💗 情绪", key: "mood")
                    chip("📔 小本本", key: "book")
                }
            }.padding(.horizontal, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headline
                    questionCard

                    HStack(spacing: 10) {
                        Button { showDoodle = true } label: {
                            Text("🖌 互动画板").font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 44)
                                .background(RoundedRectangle(cornerRadius: 24).fill(C.purple))
                        }
                        Button { sendMiss() } label: {
                            Text("💗 想你了").font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 44)
                                .background(RoundedRectangle(cornerRadius: 24).fill(Color(hex: 0xF27BAA)))
                        }
                    }

                    NavigationLink { SummaryView() } label: {
                        Text("✨ 生成 AI 月度总结")
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 24).fill(C.purple))
                    }.padding(.top, 12)

                    let list = store.visible(tag: filter)
                    let cols = masonry(list)
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 10) { ForEach(cols.0) { NoteCard(note: $0) } }
                        VStack(spacing: 10) { ForEach(cols.1) { NoteCard(note: $0) } }
                    }.padding(.top, 14)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 90)
            }
        }
        }
        .overlay(alignment: .bottom) {
            NavigationLink { EditView(note: nil) } label: {
                Text("＋ 记一笔秘语")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 26).fill(C.purple))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            }.padding(.horizontal, 40).padding(.bottom, 20)
        }
        .overlay(alignment: .top) {
            if let m = syncMsg {
                Text(m).font(.system(size: 13)).foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
                    .padding(.top, 60).transition(.opacity)
            }
        }
        .onAppear { question = bank.randomElement()! }
        .background(C.cream)
        .sheet(isPresented: $showDoodle) { DoodleView() }
        .overlay(alignment: .top) {
            // 收到 TA 的涂鸦弹窗
            if let img = doodleImg {
                VStack(spacing: 12) {
                    Text("TA 画给你的").font(.system(size: 16, weight: .bold)).foregroundColor(C.textDark)
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(maxHeight: 420).clipShape(RoundedRectangle(cornerRadius: 14))
                    Button("收到啦") { withAnimation { doodleImg = nil } }
                        .foregroundColor(.white).frame(width: 160, height: 40)
                        .background(Capsule().fill(C.purple))
                }
                .padding(20).background(RoundedRectangle(cornerRadius: 20).fill(.white).shadow(radius: 10))
                .padding(30)
            }
        }
        .alert("💗 心跳提醒", isPresented: $missAlert) {
            Button("马上回", role: .cancel) {}
        } message: { Text("TA 在想你了！快去回一句吧～") }
        .onReceive(pollTimer) { _ in
            if scenePhase == .active { pollSignals() }
        }
    }

    var headline: some View {
        let list = store.visible(tag: filter)
        return (Text("\(list.count)条关于")
            + Text(store.nick).foregroundColor(C.purple).bold()
            + Text("的秘语"))
            .font(.system(size: 20, weight: .bold)).foregroundColor(C.textDark)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .overlay(alignment: .bottomLeading) {
                Rectangle().fill(C.purple).frame(width: 88, height: 4).offset(y: 6)
            }
            .padding(.bottom, 10)
    }

    var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("想了解 TA 多一点").font(.system(size: 13)).foregroundColor(C.textGray)
            Text(question).font(.system(size: 15, weight: .bold))
                .foregroundColor(C.textDark).lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(C.purpleSoft))
        .onTapGesture { withAnimation { question = bank.randomElement()! } }
        .padding(.top, 16)
    }

    func chip(_ label: String, key: String?) -> some View {
        let on = filter == key || (key == nil && filter == nil)
        return Text(label).font(.system(size: 13))
            .foregroundColor(on ? C.purpleDeep : C.textGray)
            .padding(.horizontal, 14).frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(on ? C.purpleSoft : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 20)
                        .stroke(on ? C.purple : Color.gray.opacity(0.35), lineWidth: 1.2))
            )
            .onTapGesture { filter = key }
    }

    func masonry(_ list: [Note]) -> ([Note], [Note]) {
        var a: [Note] = [], b: [Note] = []
        for (i, n) in list.enumerated() { if i % 2 == 0 { a.append(n) } else { b.append(n) } }
        return (a, b)
    }

    func syncNow() {
        syncing = true
        Task {
            do {
                let msg = try await SyncEngine.sync()
                await MainActor.run { withAnimation { syncMsg = msg; syncing = false } }
            } catch {
                await MainActor.run { withAnimation { syncMsg = "同步失败：\(error.localizedDescription)"; syncing = false } }
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run { withAnimation { syncMsg = nil } }
        }
    }

    func sendMiss() {
        Task {
            do {
                try await Signal.send("miss")
                await MainActor.run { withAnimation { syncMsg = "💗 想念已发出，TA 的手机会震一下" } }
            } catch {
                await MainActor.run { withAnimation { syncMsg = "发送失败：\(error.localizedDescription)" } }
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run { withAnimation { syncMsg = nil } }
        }
    }

    func pollSignals() {
        guard doodleImg == nil else { return }
        Task {
            let msgs = await Signal.poll()
            for m in msgs where !handled.contains(m.file) {
                handled.insert(m.file)
                Signal.consume(m)
                switch m.type {
                case "miss":
                    await MainActor.run { Signal.vibrate(); missAlert = true }
                case "doodle":
                    if let b64 = m.imgB64, let data = Data(base64Encoded: b64),
                       let img = UIImage(data: data) {
                        await MainActor.run { withAnimation { doodleImg = img } }
                    }
                default: break
                }
            }
        }
    }
}

struct NoteCard: View {
    @ObservedObject var store = Store.shared
    let note: Note
    @State private var player: AVAudioPlayer?
    @State private var playing = false
    @State private var showReview = false
    @State private var reviewText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(note.tag == "mood" ? "💗" : note.tag == "book" ? "📔" : "☀")
                Text(dateStr).font(.system(size: 12)).foregroundColor(C.textGray)
                Spacer()
                Menu {
                    if note.audio != nil && (note.trans ?? "").isEmpty {
                        Button("语音转文字") { doTranscribe() }
                    }
                    Button("AI 点评") { doReview() }
                    Button("删除", role: .destructive) { store.softDelete(note) }
                } label: { Image(systemName: "ellipsis") .foregroundColor(C.textGray) }
            }
            if !note.text.isEmpty {
                Text(note.text).font(.system(size: 14)).foregroundColor(C.textDark).lineSpacing(4)
            }
            if note.audio != nil {
                Button(action: togglePlay) {
                    HStack {
                        Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: 13))
                        WaveShape(phase: playing ? 999 : 0).stroke(.white, lineWidth: 1.5)
                        Text("\(Int(note.dur / 1000))s").font(.system(size: 13))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).frame(height: 44).frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 24).fill(C.purple))
                }
            }
            if let t = note.trans, !t.isEmpty {
                Text("📝 " + t).font(.system(size: 12))
                    .foregroundColor(C.purpleDeep)
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(C.purpleSoft))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white).shadow(color: .black.opacity(0.06), radius: 4, y: 2))
        .alert("AI 点评", isPresented: $showReview) {
            Button("好的", role: .cancel) {}
        } message: { Text(reviewText) }
        .onChange(of: playing) { p in if !p { player?.stop(); player = nil } }
    }

    var dateStr: String {
        let f = DateFormatter(); f.dateFormat = "MM-dd"
        return f.string(from: Date(timeIntervalSince1970: note.ts / 1000))
    }

    func togglePlay() {
        if playing { playing = false; return }
        guard let a = note.audio else { return }
        do {
            let p = Store.shared.audioURL(a)
            player = try AVAudioPlayer(contentsOf: p)
            player?.play()
            playing = true
            player?.delegate = PlayerDone.shared.onDone { playing = false }
        } catch { playing = false }
    }

    func doTranscribe() {
        guard let a = note.audio else { return }
        Task {
            let url = Store.shared.audioURL(a)
            if let t = try? await Llm.transcribe(fileURL: url) {
                var n = note; n.trans = t; Store.shared.save(n)
            }
        }
    }

    func doReview() {
        Task {
            var content = "[\(dateStr)] \(note.text)"
            if let t = note.trans, !t.isEmpty { content += "（语音转写：\(t)）" }
            if let r = try? await Llm.chat(system: "你是一对情侣的贴心 AI 伙伴，说话温柔俏皮。用简体中文。",
                                           user: "这是我们的一条日常记录：\n\(content)\n\n请用 80 字以内温柔地点评和回应这条记录。") {
                await MainActor.run { reviewText = r; showReview = true }
            } else {
                await MainActor.run { reviewText = "AI 出错了，检查一下设置里的接口配置"; showReview = true }
            }
        }
    }
}

final class PlayerDone: NSObject, AVAudioPlayerDelegate {
    static let shared = PlayerDone()
    private var handler: (() -> Void)?
    func onDone(_ h: @escaping () -> Void) -> PlayerDone { handler = h; return self }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { handler?() }
}

struct WaveShape: Shape {
    var phase: Double
    func path(in r: CGRect) -> Path {
        var p = Path()
        let n = Int(r.width / 7)
        for i in 0...max(n, 1) {
            let x = r.minX + CGFloat(i) * 7
            let amp = abs(sin(Double(i) * 0.9 + phase)) * 0.7 + 0.3
            let h = r.height * CGFloat(amp)
            p.move(to: CGPoint(x: x, y: r.midY - h / 2))
            p.addLine(to: CGPoint(x: x, y: r.midY + h / 2))
        }
        return p
    }
}
