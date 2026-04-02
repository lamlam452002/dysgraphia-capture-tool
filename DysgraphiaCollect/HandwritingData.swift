import Foundation
import CoreGraphics
import PencilKit

/// Đại diện cho một điểm lấy mẫu duy nhất từ Apple Pencil
struct StrokePoint: Codable, Identifiable {
    var id = UUID()
    let x: Double
    let y: Double
    let timeOffset: TimeInterval
    let force: Double
    let azimuth: Double   // Góc xoay ngang của bút
    let altitude: Double  // Góc nghiêng dọc của bút
    
    // Các chỉ số tính toán (tính sau khi nét vẽ hoàn thành)
    var speed: Double?
    var acceleration: Double?
}

/// Đại diện cho một nét vẽ hoàn chỉnh (Stroke)
struct HandwritingStroke: Codable, Identifiable {
    var id = UUID()
    var points: [StrokePoint]
    
    // Tổng hợp các chỉ số cho nét vẽ này
    var averageSpeed: Double = 0
    var averageTilt: Double = 0
    var jitterMetric: Double = 0
}

/// Đại diện cho một phiên làm việc (Session) thu thập dữ liệu
struct HandwritingSession: Codable, Identifiable {
    var id = UUID()
    let studentID: String
    let timestamp: Date
    var strokes: [HandwritingStroke] = []
    
    var fileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "DysgraphiaData_\(studentID)_\(formatter.string(from: timestamp))"
    }
}
