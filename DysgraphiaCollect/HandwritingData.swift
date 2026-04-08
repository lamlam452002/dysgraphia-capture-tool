import Foundation
import CoreGraphics
import PencilKit

/// Đại diện cho một điểm lấy mẫu duy nhất từ Apple Pencil
struct StrokePoint: Codable, Identifiable, Hashable {
    let id: UUID
    let x: Double
    let y: Double
    let timeOffset: TimeInterval
    let force: Double
    let azimuth: Double
    let altitude: Double
    var speed: Double? // Tính toán hậu kỳ
    
    init(id: UUID = UUID(), x: Double, y: Double, timeOffset: TimeInterval, force: Double, azimuth: Double, altitude: Double, speed: Double? = nil) {
        self.id = id
        self.x = x
        self.y = y
        self.timeOffset = timeOffset
        self.force = force
        self.azimuth = azimuth
        self.altitude = altitude
        self.speed = speed
    }
}

/// Đại diện cho một nét vẽ hoàn chỉnh với các chỉ số thống kê
struct HandwritingStroke: Codable, Identifiable, Hashable {
    let id: UUID
    let points: [StrokePoint]
    
    // Các chỉ số tính toán cho chuyên gia
    let averageSpeed: Double
    let averageTilt: Double
    let jitterMetric: Double
    
    // Các rà soát hình học tự động (Graphonomics)
    var height: Double?             // Consistency: Chiều cao hộp nét chữ
    var baselineY: Double?          // Alignment: Điểm Y thấp nhất (đáy) của nét vẽ
    var spacingToPrevious: Double?  // Spacing: Khoảng cách từ lề phải của nét trước tới lề trái nét hiện tại
    
    init(id: UUID = UUID(), points: [StrokePoint], averageSpeed: Double, averageTilt: Double, jitterMetric: Double, height: Double? = nil, baselineY: Double? = nil, spacingToPrevious: Double? = nil) {
        self.id = id
        self.points = points
        self.averageSpeed = averageSpeed
        self.averageTilt = averageTilt
        self.jitterMetric = jitterMetric
        self.height = height
        self.baselineY = baselineY
        self.spacingToPrevious = spacingToPrevious
    }
}

/// Chứa các nhãn dữ liệu từ chuyên gia
struct ReviewAnnotation: Codable, Hashable {
    var isReviewed: Bool = false
    var legibilityScore: Int = 0
    var spacingScore: Int = 0
    var sizeConsistencyScore: Int = 0
    var lineAlignmentScore: Int = 0
    var pressureScore: Int = 0
    var notes: String = ""
}

/// Một phiên làm việc đầy đủ của học sinh
struct HandwritingSession: Codable, Identifiable, Hashable {
    let id: UUID
    let studentID: String
    let timestamp: Date
    var strokes: [HandwritingStroke] // Phải là var để có thể thêm nét vẽ khi vẽ
    var annotation: ReviewAnnotation
    
    init(id: UUID = UUID(), studentID: String, timestamp: Date = Date(), strokes: [HandwritingStroke] = [], annotation: ReviewAnnotation = ReviewAnnotation()) {
        self.id = id
        self.studentID = studentID
        self.timestamp = timestamp
        self.strokes = strokes
        self.annotation = annotation
    }
}
