import SwiftUI

struct PlaybackCanvas: View {
    let session: HandwritingSession
    @Binding var currentTime: TimeInterval
    
    var body: some View {
        Canvas { context, size in
            var latestPoint: StrokePoint?
            
            for stroke in session.strokes {
                let points = stroke.points.filter { $0.timeOffset <= currentTime }
                guard !points.isEmpty else { continue }
                
                var path = Path()
                path.move(to: CGPoint(x: points[0].x, y: points[0].y))
                
                for i in 1..<points.count {
                    path.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
                }
                
                // Nét vẽ chính
                context.stroke(path, with: .color(.primary.opacity(0.8)), lineWidth: 2)
                
                // Tìm kiếm điểm mới nhất trên toàn bộ mặt phẳng
                if let lastPoint = points.last {
                    if latestPoint == nil || lastPoint.timeOffset > latestPoint!.timeOffset {
                        latestPoint = lastPoint
                    }
                }
            }
            
            // Chỉ báo điểm Mới nhất (ngòi bút)
            // Chỉ vẽ Bóng Bút nếu tại thời điểm `currentTime` này, cây bút đang thực sự di chuyển 
            // (Chênh lệch giữa thời gian điểm gần nhất và mốc slider phải nhỏ, tránh vẽ bóng bút ảo lúc đang nghỉ giải lao)
            if let activePoint = latestPoint, (currentTime - activePoint.timeOffset) < 0.15 {
                drawPenIndicator(context: context, point: activePoint)
            }
        }
        .background(Color.white)
        .drawingGroup() // Tối ưu hiệu năng rendering
    }
    
    private func drawPenIndicator(context: GraphicsContext, point: StrokePoint) {
        let center = CGPoint(x: point.x, y: point.y)
        
        // 1. Vòng tròn hiển thị lực nhấn (Force)
        let forceRadius = CGFloat(5 + (point.force * 15))
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - forceRadius/2, y: point.y - forceRadius/2, width: forceRadius, height: forceRadius)),
            with: .color(.blue.opacity(0.3))
        )
        
        // 2. Chỉ báo hướng và độ nghiêng (Azimuth & Altitude)
        // Vẽ một "bóng" của bút dựa trên góc nghiêng và hướng
        let length = CGFloat(30 * cos(point.altitude))
        let dx = length * cos(point.azimuth)
        let dy = length * sin(point.azimuth)
        
        var tiltPath = Path()
        tiltPath.move(to: center)
        tiltPath.addLine(to: CGPoint(x: point.x + dx, y: point.y + dy))
        
        context.stroke(
            tiltPath,
            with: .color(.orange),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
        )
        
        // Điểm tiếp xúc chính xác
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)),
            with: .color(.blue)
        )
    }
}
