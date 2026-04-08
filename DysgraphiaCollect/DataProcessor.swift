import Foundation
import PencilKit
import CoreGraphics

class DataProcessor {
    
    /// Chuyển đổi PKStroke thành HandwritingStroke kèm theo các chỉ số tính toán thời gian thực (Global Time)
    static func process(pkStroke: PKStroke, baseCreationDate: Date, idleGap: TimeInterval) -> HandwritingStroke {
        let pkPoints = pkStroke.path.map { $0 }
        var strokePoints: [StrokePoint] = []
        
        // Tính toán khoảng cách thời gian giữa nét hiện tại so với NÉT ĐẦU TIÊN (Dùng chung đồng hồ của PencilKit)
        let strokeStartTime = pkStroke.path.creationDate
        let strokeDelayFromFirstTouch = strokeStartTime.timeIntervalSince(baseCreationDate)
        
        // 1. Chuyển đổi sang mô hình dữ liệu của chúng ta
        for pkPoint in pkPoints {
            // Global Time = Thời gian chờ ban đầu + Khoảng cách giữa các nét vẽ + Thời gian li ti của từng pixel
            let globalTimeOffset = idleGap + max(0, strokeDelayFromFirstTouch) + pkPoint.timeOffset
            
            let point = StrokePoint(
                x: Double(pkPoint.location.x),
                y: Double(pkPoint.location.y),
                timeOffset: globalTimeOffset,
                force: Double(pkPoint.force),
                azimuth: Double(pkPoint.azimuth),
                altitude: Double(pkPoint.altitude)
            )
            strokePoints.append(point)
        }
        
        // 2. Tính toán tốc độ giữa các điểm
        for i in 1..<strokePoints.count {
            let p1 = strokePoints[i-1]
            let p2 = strokePoints[i]
            
            let dist = distance(x1: p1.x, y1: p1.y, x2: p2.x, y2: p2.y)
            let dt = p2.timeOffset - p1.timeOffset
            
            if dt > 0 {
                strokePoints[i].speed = dist / dt
            }
        }
        
        // 3. Tính toán các chỉ số trung bình và Jitter
        let speeds = strokePoints.compactMap { $0.speed }
        let avgSpeed = speeds.reduce(0, +) / Double(max(1, speeds.count))
        let avgTilt = strokePoints.map { $0.altitude }.reduce(0, +) / Double(max(1, strokePoints.count))
        
        // Jitter Metric: Độ lệch chuẩn của tốc độ hoặc độ lệch so với đường trung bình
        // Ở đây chúng ta dùng độ biến thiên của tốc độ (Acceleration jitter)
        let jitter = calculateJitter(points: strokePoints)
        
        return HandwritingStroke(
            points: strokePoints,
            averageSpeed: avgSpeed,
            averageTilt: avgTilt,
            jitterMetric: jitter
        )
    }
    
    private static func distance(x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
        return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2))
    }
    
    /// Tính toán độ giật (Jitter) dựa trên sự biến thiên của gia tốc hoặc hướng
    private static func calculateJitter(points: [StrokePoint]) -> Double {
        guard points.count > 2 else { return 0 }
        
        var speedVariations: [Double] = []
        for i in 2..<points.count {
            if let v1 = points[i-1].speed, let v2 = points[i].speed {
                // Sự thay đổi tốc độ đột ngột
                speedVariations.append(abs(v2 - v1))
            }
        }
        
        if speedVariations.isEmpty { return 0 }
        
        // Trả về trung bình của các biến thiên tốc độ (có thể coi là một chỉ số jitter thô)
        return speedVariations.reduce(0, +) / Double(speedVariations.count)
    }
}
