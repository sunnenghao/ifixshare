import SwiftUI

/// 画板：手指涂鸦，可撤回/清空/换色，发送后对方 App 弹窗显示。
struct DoodleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var strokes: [Stroke] = []
    @State private var current: Stroke? = nil
    @State private var color = C.purpleDeep
    @State private var sending = false
    @State private var toast: String? = nil

    struct Stroke: Identifiable {
        let id = UUID()
        let color: Color
        var points: [CGPoint]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("‹") { dismiss() }.font(.system(size: 26)).foregroundColor(C.textDark)
                Spacer()
                Text("画给 TA").font(.system(size: 18, weight: .bold)).foregroundColor(C.textDark)
                Spacer()
                Button("↩") { if !strokes.isEmpty { strokes.removeLast() } }
                    .font(.system(size: 20)).foregroundColor(C.textDark)
            }.padding(.horizontal, 18).frame(height: 56)

            HStack(spacing: 12) {
                dot(C.purpleDeep); dot(Color(hex: 0xE85D75)); dot(Color(hex: 0xF5A623))
                dot(Color(hex: 0x7AC74F)); dot(Color(hex: 0x4A90D9)); dot(Color(hex: 0x3B3B4F))
                Spacer()
                Button("清空") { strokes.removeAll() }.foregroundColor(C.textGray)
            }.padding(.horizontal, 18)

            Canvas { ctx, _ in
                for s in strokes { draw(s, into: &ctx) }
                if let c = current { draw(c, into: &ctx) }
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xF6EFE6))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.3), lineWidth: 1.5)))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if current == nil { current = Stroke(color: color, points: []) }
                        current?.points.append(v.location)
                    }
                    .onEnded { _ in
                        if let c = current { strokes.append(c) }
                        current = nil
                    }
            )
            .padding(.horizontal, 16).padding(.vertical, 12)

            Button {
                send()
            } label: {
                HStack { if sending { ProgressView().tint(.white).padding(.trailing, 4) }
                    Text("发送 ➤") }
                    .foregroundColor(.white).font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: 24).fill(strokes.isEmpty ? Color.gray : C.purple))
            }
            .disabled(sending || strokes.isEmpty)
            .padding(.horizontal, 18).padding(.bottom, 20)
        }
        .overlay(alignment: .center) {
            if let t = toast {
                Text(t).font(.system(size: 14)).foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
            }
        }
        .background(C.cream)
    }

    func dot(_ c: Color) -> some View {
        Circle().fill(c).frame(width: 30, height: 30)
            .overlay(Circle().stroke(color == c ? C.textDark : .clear, lineWidth: 2.5))
            .onTapGesture { color = c }
    }

    func draw(_ s: Stroke, into ctx: inout GraphicsContext) {
        guard s.points.count > 1 else {
            if let p = s.points.first {
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(s.color))
            }
            return
        }
        var path = Path()
        path.move(to: s.points[0])
        for pt in s.points.dropFirst() { path.addLine(to: pt) }
        ctx.stroke(path, with: .color(s.color), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
    }

    func renderImage() -> UIImage? {
        let size = CGSize(width: 720, height: 900)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(hex: 0xF6EFE6).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let scale = min(720 / max(UIScreen.main.bounds.width - 32, 1), 900 / 900)
            for s in strokes {
                UIColor(s.color).setFill()
                UIColor(s.color).setStroke()
                let pts = s.points.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
                guard pts.count > 1 else {
                    if let p = pts.first { ctx.cgContext.fillEllipse(in: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)) }
                    continue
                }
                let path = UIBezierPath()
                path.move(to: pts[0])
                for pt in pts.dropFirst() { path.addLine(to: pt) }
                path.lineWidth = 10; path.lineCapStyle = .round
                path.stroke()
            }
        }
    }

    func send() {
        guard let img = renderImage(),
              let data = img.pngData(),
              let b64 = data.base64EncodedString() as String? else { return }
        sending = true
        Task {
            do {
                try await Signal.send("doodle", imgB64: b64)
                await MainActor.run { toast = "画好啦，等 TA 打开 App 就能看到～"; sending = false }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run { toast = "发送失败：\(error.localizedDescription)"; sending = false }
            }
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
