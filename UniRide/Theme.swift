import SwiftUI

// Colors and shared components recovered from the original Canva mockups.
enum UniRideTheme {
    static let lime = Color(red: 0.63, green: 1, blue: 0.22)
    static let background = Color.black
    static let card = Color(red: 0.15, green: 0.15, blue: 0.15)
    static let field = Color(red: 0.30, green: 0.30, blue: 0.30)
    static let muted = Color(red: 0.62, green: 0.62, blue: 0.62)
}

struct UniRideLogo: View {
    var size: CGFloat = 88
    var glow = false
    var body: some View {
        Image("UniRideLogo")
            .resizable().scaledToFit().frame(width: size, height: size * 1.19)
            .shadow(color: glow ? UniRideTheme.lime.opacity(0.7) : .clear, radius: 20)
            .accessibilityLabel("UniRide")
    }
}

struct LimeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity).frame(minHeight: 50)
            .background(UniRideTheme.lime, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct NetworkBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date()

    // Deterministic seeds keep the network continuous when a form field changes.
    private let points: [CGPoint] = (0..<54).map { i in
        let x = Double((i * i * 31 + i * 73 + 19) % 997) / 996
        let y = Double((i * i * 17 + i * 37 + 7) % 991) / 990
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { timeline in
            let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSince(startedAt)
            ZStack {
                Color.black
                RadialGradient(colors: [UniRideTheme.lime.opacity(0.22), .clear], center: .init(x: 0.5, y: 0.32), startRadius: 0, endRadius: 190)
                Canvas(rendersAsynchronously: true) { context, size in
                    let positions = points.enumerated().map { i, point in
                        let phase = Double(i) * 2.399
                        return CGPoint(
                            x: point.x * size.width + sin(elapsed * 0.22 + phase) * 28,
                            y: point.y * size.height + cos(elapsed * 0.18 + phase) * 35
                        )
                    }
                    for i in positions.indices {
                        for j in positions.indices where j > i {
                            let distance = hypot(positions[i].x - positions[j].x, positions[i].y - positions[j].y)
                            if distance < 155 {
                                var path = Path()
                                path.move(to: positions[i])
                                path.addLine(to: positions[j])
                                context.stroke(path, with: .color(UniRideTheme.lime.opacity(0.45 * (1 - Double(distance) / 155))), lineWidth: 0.7)
                            }
                        }
                        drawBanknote(in: context, at: positions[i], index: i, elapsed: elapsed)
                    }
                }
                LinearGradient(colors: [.clear, .black.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }

    private func drawBanknote(in context: GraphicsContext, at position: CGPoint, index: Int, elapsed: Double) {
        var note = context
        note.translateBy(x: position.x, y: position.y)
        note.rotate(by: .radians(Double(index) * 0.73 + sin(elapsed * 0.16 + Double(index)) * 0.4))
        let scale = index % 3 == 0 ? 1.1 : 0.8
        note.scaleBy(x: scale, y: scale)
        let outline = Path(roundedRect: CGRect(x: -8, y: -5.5, width: 16, height: 11), cornerRadius: 3)
        note.addFilter(.shadow(color: UniRideTheme.lime.opacity(0.5), radius: 3))
        note.fill(outline, with: .color(Color(red: 0.86, green: 1, blue: 0.58)))
        note.stroke(Path(roundedRect: CGRect(x: -6, y: -3.5, width: 12, height: 7), cornerRadius: 1.5), with: .color(UniRideTheme.lime.opacity(0.95)), lineWidth: 0.8)
        note.draw(Text("$").font(.system(size: 7, weight: .bold)).foregroundColor(Color(red: 0.36, green: 0.59, blue: 0.08)), at: .zero)
    }
}

extension View {
    func uniRideField() -> some View {
        self.font(.system(size: 15)).padding(.horizontal, 16).frame(minHeight: 52)
            .background(UniRideTheme.field.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
    }
}
