import SwiftUI
import Charts

struct TelemetryChartView: View {
    let session: HandwritingSession
    @Binding var currentTime: TimeInterval
    
    // Model chung cho biểu đồ để tránh lỗi kiểu dữ liệu bộ dữ liệu (tuples)
    struct ChartPoint: Identifiable {
        let id = UUID()
        let time: TimeInterval
        let value: Double
        let strokeID: String
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. Lực nhấn (Force)
                MetricChartSection(
                    title: "Pen Pressure (Force)",
                    units: "0.0 - 1.0",
                    color: .orange,
                    currentTime: currentTime,
                    data: session.strokes.flatMap { stroke in
                        stroke.points.map { ChartPoint(time: $0.timeOffset, value: $0.force, strokeID: stroke.id.uuidString) }
                    }
                ) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Force", point.value)
                    )
                    .foregroundStyle(by: .value("Stroke", point.strokeID))
                }
                
                // 2. Tốc độ (Speed)
                MetricChartSection(
                    title: "Stroke Speed",
                    units: "px/s",
                    color: .blue,
                    currentTime: currentTime,
                    data: session.strokes.flatMap { stroke in
                        stroke.points.compactMap { p in
                            p.speed.map { ChartPoint(time: p.timeOffset, value: $0, strokeID: stroke.id.uuidString) }
                        }
                    }
                ) { point in
                    AreaMark(
                        x: .value("Time", point.time),
                        y: .value("Speed", point.value)
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                    
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Speed", point.value)
                    )
                }
                
                // 3. Độ nghiêng (Altitude/Tilt)
                MetricChartSection(
                    title: "Pen Tilt (Altitude)",
                    units: "rad",
                    color: .purple,
                    currentTime: currentTime,
                    data: session.strokes.flatMap { stroke in
                        stroke.points.map { ChartPoint(time: $0.timeOffset, value: $0.altitude, strokeID: stroke.id.uuidString) }
                    }
                ) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Tilt", point.value)
                    )
                }
                
                // 4. Hướng bút (Azimuth)
                MetricChartSection(
                    title: "Pen Azimuth (Angle)",
                    units: "rad",
                    color: .teal, // Dùng màu Teal để dễ phân biệt với các biểu đồ khác
                    currentTime: currentTime,
                    data: session.strokes.flatMap { stroke in
                        stroke.points.map { ChartPoint(time: $0.timeOffset, value: $0.azimuth, strokeID: stroke.id.uuidString) }
                    }
                ) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Azimuth", point.value)
                    )
                    .foregroundStyle(.teal)
                }
                
                // 5. Độ đồng đều (Consistency - Stroke Height)
                MetricChartSection(
                    title: "Size Consistency (Stroke Height)",
                    units: "px",
                    color: .green,
                    currentTime: currentTime,
                    data: session.strokes.compactMap { stroke in
                        guard let h = stroke.height, let t = stroke.points.first?.timeOffset else { return nil }
                        return ChartPoint(time: t, value: h, strokeID: stroke.id.uuidString)
                    }
                ) { point in
                    BarMark(
                        x: .value("Time", point.time),
                        y: .value("Height", point.value),
                        width: .fixed(6)
                    )
                    .foregroundStyle(.green)
                }
                
                // 6. Căn lề / Viết lệch dòng (Alignment - Baseline)
                MetricChartSection(
                    title: "Alignment (Baseline Drift)",
                    units: "px",
                    color: .red,
                    currentTime: currentTime,
                    data: session.strokes.compactMap { stroke in
                        guard let b = stroke.baselineY, let t = stroke.points.first?.timeOffset else { return nil }
                        return ChartPoint(time: t, value: b, strokeID: stroke.id.uuidString)
                    }
                ) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Baseline", point.value)
                    )
                    .foregroundStyle(.red)
                    
                    PointMark(
                        x: .value("Time", point.time),
                        y: .value("Baseline", point.value)
                    )
                    .foregroundStyle(.red)
                }
                
                // 7. Mật độ giãn cách chữ (Spacing)
                MetricChartSection(
                    title: "Spacing (Gap to Previous Stroke)",
                    units: "px",
                    color: .yellow,
                    currentTime: currentTime,
                    data: session.strokes.compactMap { stroke in
                        guard let s = stroke.spacingToPrevious, let t = stroke.points.first?.timeOffset else { return nil }
                        return ChartPoint(time: t, value: s, strokeID: stroke.id.uuidString)
                    }
                ) { point in
                    BarMark(
                        x: .value("Time", point.time),
                        y: .value("Spacing Gap", point.value),
                        width: .fixed(4)
                    )
                    .foregroundStyle(.yellow)
                }
                
                // 8. Tremor Index (Run tay)
                tremorIndexSummary
            }
        }
    }
    
    private var tremorIndexSummary: some View {
        MetricChartSection(
            title: "Tremor Index",
            units: "pt/s",
            color: .pink,
            currentTime: currentTime,
            data: session.strokes.compactMap { stroke in
                let j = stroke.tremorIndex
                guard let t = stroke.points.first?.timeOffset else { return nil }
                return ChartPoint(time: t, value: j, strokeID: stroke.id.uuidString)
            }
        ) { point in
            LineMark(
                x: .value("Time", point.time),
                y: .value("Tremor", point.value)
            )
            .foregroundStyle(.pink)
            
            AreaMark(
                x: .value("Time", point.time),
                y: .value("Tremor", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.pink.opacity(0.3), .pink.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

/// Thành phần biểu đồ chung để tái sử dụng
struct MetricChartSection<Content: ChartContent>: View {
    let title: String
    let units: String
    let color: Color
    let currentTime: TimeInterval
    let data: [TelemetryChartView.ChartPoint]
    @ChartContentBuilder var content: (TelemetryChartView.ChartPoint) -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.bold())
                Spacer()
                Text(units)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Chart {
                ForEach(data) { point in
                    content(point)
                        .interpolationMethod(.monotone)
                }
                
                RuleMark(x: .value("Current", currentTime))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 2]))
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5))
            }
            .frame(height: 100)
            .padding(.top, 4)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
        .padding(.horizontal)
    }
}
