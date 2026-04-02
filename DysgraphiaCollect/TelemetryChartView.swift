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
                
                // 4. Jitter Summary
                jitterSummary
            }
        }
    }
    
    private var jitterSummary: some View {
        VStack(alignment: .leading) {
            Text("Jitter Analysis per Stroke")
                .font(.caption.bold())
                .padding(.horizontal)
            
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(session.strokes) { stroke in
                    VStack {
                        Text("\(stroke.jitterMetric, specifier: "%.1f")")
                            .font(.system(size: 8, design: .monospaced))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(stroke.jitterMetric > 5 ? Color.red : Color.green)
                            .frame(width: 20, height: CGFloat(min(100, stroke.jitterMetric * 4)))
                    }
                }
            }
            .padding()
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
        .padding(.horizontal)
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
