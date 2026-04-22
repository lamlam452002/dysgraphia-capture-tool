import Foundation
import PencilKit
import CoreGraphics

class DataProcessor {
    
    /// Chuyển đổi PKStroke thành HandwritingStroke kèm theo các chỉ số tính toán thời gian thực (Global Time) và Hình học (Graphonomics)
    static func process(pkStroke: PKStroke, baseCreationDate: Date, idleGap: TimeInterval, previousStroke: HandwritingStroke? = nil) -> HandwritingStroke {
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
        
        // 2. Tính toán tốc độ giữa các điểm với bộ lọc nhiễu thời gian
        let minDT: TimeInterval = 0.006 // Ngưỡng tối thiểu (500Hz) để tránh spike vận tốc do dt siêu nhỏ
        for i in 1..<strokePoints.count {
            let p1 = strokePoints[i-1]
            let p2 = strokePoints[i]
            
            let dist = distance(x1: p1.x, y1: p1.y, x2: p2.x, y2: p2.y)
            let dt = p2.timeOffset - p1.timeOffset
            
            if dt >= minDT {
                strokePoints[i].speed = dist / dt
            } else if i > 1 {
                // Nếu dt quá nhỏ, mượn speed của điểm trước đó để duy trì tính liên tục
                strokePoints[i].speed = strokePoints[i-1].speed
            }
        }
        
        // 3. Tính toán các chỉ số trung bình và Tremor Index (với làm mượt)
        let speeds = strokePoints.compactMap { $0.speed }
        let avgSpeed = speeds.reduce(0, +) / Double(max(1, speeds.count))
        let avgTilt = strokePoints.map { $0.altitude }.reduce(0, +) / Double(max(1, strokePoints.count))
        
        // Tremor Index: Biến thiên vận tốc tức thời (đã được làm mượt)
        let tremorIndex = calculateJitter(points: strokePoints)
        
        // 4. Các tính toán Graphonomics tự động (Image Space: Hình học không gian)
        let xs = strokePoints.map { $0.x }
        let ys = strokePoints.map { $0.y }
        
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        
        let height = maxY - minY
        let baselineY = maxY // Trong hệ tọa độ iOS, Y max nằm ở dưới đáy màn hình
        
        var spacing: Double? = nil
        if let prevStroke = previousStroke {
            let prevXs = prevStroke.points.map { $0.x }
            let prevMaxX = prevXs.max() ?? 0
            spacing = minX - prevMaxX // Khoảng cách giãn chữ theo trục ngang
        }
        
        return HandwritingStroke(
            points: strokePoints,
            averageSpeed: avgSpeed,
            averageTilt: avgTilt,
            tremorIndex: tremorIndex,
            height: height,
            baselineY: baselineY,
            spacingToPrevious: spacing
        )
    }
    
    private static func distance(x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
        return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2))
    }
    
    /// Tính toán độ giật (Jitter/Tremor) dựa trên sự biến thiên vận tốc đã được làm mượt
    private static func calculateJitter(points: [StrokePoint]) -> Double {
        let rawSpeeds = points.compactMap { $0.speed }
        guard rawSpeeds.count > 3 else { return 0 }
        
        // Làm mượt vận tốc bằng Moving Average (cửa sổ 3 điểm) để lọc nhiễu sensor
        var smoothedSpeeds: [Double] = []
        for i in 1..<(rawSpeeds.count - 1) {
            let avg = (rawSpeeds[i-1] + rawSpeeds[i] + rawSpeeds[i+1]) / 3.0
            smoothedSpeeds.append(avg)
        }
        
        var variations: [Double] = []
        for i in 1..<smoothedSpeeds.count {
            let diff = abs(smoothedSpeeds[i] - smoothedSpeeds[i-1])
            // Giới hạn vật lý: Một cú giật (variation) không thể quá 200 pt/s trong 0.01s (trừ khi là rác dữ liệu)
            if diff < 200 {
                variations.append(diff)
            }
        }
        
        if variations.isEmpty { return 0 }
        
        let avgJitter = variations.reduce(0, +) / Double(variations.count)
        
        // Capping cuối cùng: Giới hạn Tremor Index thực tế tối đa là 100
        // (Đây là ngưỡng cực kỳ cao, thường gặp ở bệnh nhân Parkinson nặng)
        return min(avgJitter, 100.0)
    }
}
