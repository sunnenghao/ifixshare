import SwiftUI
import AVFoundation

struct EditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store = Store.shared
    let existing: Note?

    @State private var text = ""
    @State private var tag = "daily"
    @State private var recording = false
    @State private var recSecs = 0
    @State private var audioName: String? = nil
    @State private var audioDur: Double = 0
    @State private var trans: String? = nil

    @State private var recorder: AVAudioRecorder?
    @State private var player: AVAudioPlayer?
    @State private var playing = false
    @State private var timer: Timer?

    init(note: Note?) {
        existing = note
        _text = State(initialValue: note?.text ?? "")
        _tag = State(initialValue: note?.tag ?? "daily")
        _audioName = State(initialValue: note?.audio)
        _audioDur = State(initialValue: note?.dur ?? 0)
        _trans = State(initialValue: note?.trans)
    }

    var body: some View {
        ZStack { C.cream.ignoresSafeArea() }
        VStack(spacing: 0) {
            HStack {
                Button("‹") { dismiss() }
                    .font(.system(size: 26)).foregroundColor(C.textDark)
                Spacer()
                Text(existing == nil ? "记一笔" : "编辑秘语")
                    .font(.system(size: 18, weight: .bold)).foregroundColor(C.textDark)
                Spacer()
                Button("保存") { save() }
                    .font(.system(size: 16, weight: .bold)).foregroundColor(C.purpleDeep)
            }.padding(.horizontal, 18).frame(height: 56)

            HStack(spacing: 8) {
                tagChip("☀ 日常", "daily"); tagChip("💗 情绪", "mood"); tagChip("📔 小本本", "book")
                Spacer()
            }.padding(.horizontal, 18)

            TextEditor(text: $text)
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.25), lineWidth: 1)))
                .padding(.horizontal, 18).padding(.top, 12)

            Button(action: toggleRecord) {
                HStack {
                    Image(systemName: recording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 20))
                    Text(recording ? "⏺ 正在录音 \(recSecs)s，点这里停止"
                         : (audioName != nil ? "🎙 重新录一段" : "🎙 按下开始录音"))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 23).fill(recording ? Color.red : C.purple))
            }.padding(.horizontal, 18).padding(.top, 12)

            if audioName != nil {
                HStack {
                    Button(action: play) {
                        Image(systemName: playing ? "pause.fill" : "play.fill").foregroundColor(.white)
                    }
                    WaveShape(phase: playing ? 999 : 0).stroke(.white, lineWidth: 1.5)
                    Text("\(Int(audioDur / 1000))s").foregroundColor(.white).font(.system(size: 13))
                    Button(action: deleteAudio) { Image(systemName: "trash").foregroundColor(.white) }
                }
                .padding(.horizontal, 14).frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 22).fill(C.purple))
                .padding(.horizontal, 18).padding(.top, 10)
            }
            Spacer()
        }
        .onDisappear { timer?.invalidate(); recorder?.stop(); player?.stop() }
    }

    func tagChip(_ label: String, _ key: String) -> some View {
        let on = tag == key
        return Text(label).font(.system(size: 13))
            .foregroundColor(on ? C.purpleDeep : C.textGray)
            .padding(.horizontal, 14).frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 20)
                .fill(on ? C.purpleSoft : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(on ? C.purple : Color.gray.opacity(0.35), lineWidth: 1.2)))
            .onTapGesture { tag = key }
    }

    func toggleRecord() {
        if recording { stopRecord(); return }
        AVAudioSession.sharedInstance().requestRecordPermission { ok in
            guard ok else { return }
            DispatchQueue.main.async {
                deleteAudio()
                let url = Store.shared.audioURL("\(UUID().uuidString).m4a")
                let s = AVAudioSession.sharedInstance()
                try? s.setCategory(.playAndRecord, mode: .default)
                try? s.setActive(true)
                let rec = try? AVAudioRecorder(url: url, settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderBitRateKey: 96000
                ])
                rec?.record()
                recorder = rec
                recording = true
                recSecs = 0
                audioName = url.lastPathComponent
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in recSecs += 1 }
            }
        }
    }

    func stopRecord() {
        timer?.invalidate(); timer = nil
        audioDur = Double(recSecs) * 1000
        recorder?.stop(); recorder = nil
        recording = false
    }

    func deleteAudio() {
        if let a = audioName { try? FileManager.default.removeItem(at: Store.shared.audioURL(a)) }
        audioName = nil; audioDur = 0; trans = nil
    }

    func play() {
        if playing { player?.stop(); playing = false; return }
        guard let a = audioName else { return }
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback); try? s.setActive(true)
        player = try? AVAudioPlayer(contentsOf: Store.shared.audioURL(a))
        player?.play(); playing = true
    }

    func save() {
        if recording { stopRecord() }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && audioName == nil { return }
        var n = existing ?? Note()
        n.tag = tag; n.text = text
        n.audio = audioName; n.dur = audioDur; n.trans = trans
        n.aremote = (audioName == nil) ? nil : n.aremote
        store.save(n)

        if let a = audioName, n.trans == nil, !Llm.asr.isEmpty, Llm.ready {
            let url = Store.shared.audioURL(a)
            Task {
                if let t = try? await Llm.transcribe(fileURL: url) {
                    var m = n; m.trans = t; Store.shared.save(m)
                }
            }
        }
        if WebDav.cfg() != nil {
            Task { _ = try? await SyncEngine.sync() }
        }
        dismiss()
    }
}
