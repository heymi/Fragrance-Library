import SwiftUI

// MARK: - Axis Model

struct RadarChartAxis {
    let label: String
    let value: Double  // 0...5
}

// MARK: - Background Grid

private struct RadarGrid: Shape {
    let levels: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 * 0.72
        var path = Path()

        // Concentric hexagons
        for level in 1...levels {
            let r = radius * Double(level) / Double(levels)
            var hex = Path()
            for i in 0..<6 {
                let angle = radarAngle(i)
                let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * r,
                                 y: center.y + CGFloat(sin(angle)) * r)
                if i == 0 { hex.move(to: pt) } else { hex.addLine(to: pt) }
            }
            hex.closeSubpath()
            path.addPath(hex)
        }

        // Radial lines
        for i in 0..<6 {
            let angle = radarAngle(i)
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                                      y: center.y + CGFloat(sin(angle)) * radius))
        }

        return path
    }
}

// MARK: - Animated Data Polygon

private struct RadarPolygon: Shape {
    let axes: [RadarChartAxis]
    var progress: Double  // 0 → 1

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 * 0.72

        var path = Path()
        for (i, axis) in axes.enumerated() {
            let angle = radarAngle(i)
            let r = radius * (axis.value / 5.0) * progress
            let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * r,
                             y: center.y + CGFloat(sin(angle)) * r)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Helper

private func radarAngle(_ index: Int) -> Double {
    Double(index) / 6.0 * 2 * .pi - .pi / 2
}

// MARK: - RadarChartView

struct RadarChartView: View {
    let axes: [RadarChartAxis]
    let color: Color
    var title: String = ""

    @State private var progress: Double = 0
    @State private var labelsAppeared: [Bool] = Array(repeating: false, count: 6)

    var body: some View {
        VStack(spacing: 4) {
            if !title.isEmpty {
                Text(title.uppercased())
                    .font(PerfumeType.label(10))
                    .tracking(2.2)
                    .foregroundStyle(Color.perfumeTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ZStack {
                RadarGrid(levels: 5)
                    .stroke(Color.perfumeBorder, lineWidth: 0.8)
                    .opacity(progress > 0 ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: progress)

                // Filled area
                RadarPolygon(axes: axes, progress: progress)
                    .fill(color.opacity(0.30))
                    .animation(.spring(duration: 0.65, bounce: 0.3), value: progress)

                // Stroke
                RadarPolygon(axes: axes, progress: progress)
                    .stroke(color, lineWidth: 2)
                    .animation(.spring(duration: 0.65, bounce: 0.3), value: progress)

                // Data points
                ForEach(0..<axes.count, id: \.self) { i in
                    let angle = radarAngle(i)
                    let center = CGPoint(x: 140, y: 140)
                    let radius = min(280, 280) / 2 * 0.72
                    let r = radius * (axes[i].value / 5.0) * progress
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .position(x: center.x + CGFloat(cos(angle)) * r,
                                  y: center.y + CGFloat(sin(angle)) * r)
                        .animation(.spring(duration: 0.65, bounce: 0.3), value: progress)
                }

                // Labels
                ForEach(0..<axes.count, id: \.self) { i in
                    let angle = radarAngle(i)
                    let center = CGPoint(x: 140, y: 140)
                    let labelRadius = min(280, 280) / 2 * 0.95

                    Text(axes[i].label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.perfumeTextSecondary)
                        .position(x: center.x + CGFloat(cos(angle)) * labelRadius,
                                  y: center.y + CGFloat(sin(angle)) * labelRadius)
                        .scaleEffect(labelsAppeared[i] ? 1 : 0)
                        .opacity(labelsAppeared[i] ? 1 : 0)
                        .animation(.spring(duration: 0.35, bounce: 0.4),
                                   value: labelsAppeared[i])
                }
            }
            .frame(width: 280, height: 280)
            .onAppear {
                withAnimation(.spring(duration: 0.65, bounce: 0.3)) {
                    progress = 1
                }
                for i in 0..<min(6, axes.count) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(i) * 0.05) {
                        withAnimation(.spring(duration: 0.35, bounce: 0.4)) {
                            labelsAppeared[i] = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Perfume Extension

extension Perfume {
    var radarAxes: [RadarChartAxis] {
        [
            RadarChartAxis(label: "👴 长辈", value: radarElder),
            RadarChartAxis(label: "💕 约会", value: radarDate),
            RadarChartAxis(label: "👯 闺蜜", value: radarGirlApproved),
            RadarChartAxis(label: "💼 职场", value: radarOffice),
            RadarChartAxis(label: "🧘 独处", value: radarSelf),
            RadarChartAxis(label: "✨ 初见", value: radarImpression),
        ]
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        RadarChartView(
            axes: [
                RadarChartAxis(label: "👴 长辈", value: 3),
                RadarChartAxis(label: "💕 约会", value: 4.5),
                RadarChartAxis(label: "👯 闺蜜", value: 3.5),
                RadarChartAxis(label: "💼 职场", value: 4),
                RadarChartAxis(label: "🧘 独处", value: 2.5),
                RadarChartAxis(label: "✨ 初见", value: 4),
            ],
            color: Color.perfumeAccent,
            title: "SCENE COMPASS"
        )
        .padding()
        .background(Color.perfumeCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .padding()
    .background(Color.perfumeBg)
}
