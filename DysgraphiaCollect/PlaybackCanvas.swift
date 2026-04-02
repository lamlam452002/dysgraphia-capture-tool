import SwiftUI

struct PlaybackCanvas: View {
    let session: HandwritingSession
    @Binding var currentTime: TimeInterval
    
    var body: some View {
        Canvas { context, size in
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
                
                // Chỉ báo điểm hiện tại (ngòi bút)
                if let lastPoint = points.last {
                    drawPenIndicator(context: context, point: lastPoint)
                }
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
