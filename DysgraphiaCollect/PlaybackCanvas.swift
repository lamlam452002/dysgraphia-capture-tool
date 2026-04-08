import SwiftUI

struct PlaybackCanvas: View {
    let session: HandwritingSession
    @Binding var currentTime: TimeInterval
    var showAnalysis: Bool = false // Cờ bật/tắt Lớp phân tích
    
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
                context.stroke(path, with: .color(.black), lineWidth: 2)
                
                if let lastPoint = points.last {
                    if latestPoint == nil || lastPoint.timeOffset > latestPoint!.timeOffset {
                        latestPoint = lastPoint
                    }
                }
            }
            
            // LỚP PHÂN TÍCH SINH TRẮC HỌC ĐA TẦNG (DIAGNOSTIC OVERLAY v2.0)
            if showAnalysis {
                let activeStrokes = session.strokes.filter { ($0.points.first?.timeOffset ?? .infinity) <= currentTime }
                
                // --- 1. Tính toán mốc chuẩn (Averages) ---
                let validHeights = activeStrokes.compactMap { $0.height }.filter { $0 > 0 }
                let avgHeight = validHeights.isEmpty ? 0 : validHeights.reduce(0, +) / Double(validHeights.count)
                
                let validSpacings = activeStrokes.compactMap { $0.spacingToPrevious }
                let avgSpacing = validSpacings.isEmpty ? 0 : validSpacings.reduce(0, +) / Double(validSpacings.count)
                
                let validBaselines = activeStrokes.compactMap { $0.baselineY }
                let avgBaselineY = validBaselines.isEmpty ? 0 : validBaselines.reduce(0, +) / Double(validBaselines.count)
                
                // Vẽ đường Baseline chuẩn (Ghost Line)
                if avgBaselineY > 0 {
                    var baselinePath = Path()
                    baselinePath.move(to: CGPoint(x: 0, y: avgBaselineY))
                    baselinePath.addLine(to: CGPoint(x: size.width, y: avgBaselineY))
                    context.stroke(baselinePath, with: .color(.red.opacity(0.1)), style: StrokeStyle(lineWidth: 1, dash: [10, 5]))
                }
                
                // --- 2. Duyệt từng nét để bắt lỗi ---
                for stroke in activeStrokes {
                    let points = stroke.points.filter { $0.timeOffset <= currentTime }
                    guard !points.isEmpty else { continue }
                    
                    let strokeMinX = points.map { $0.x }.min() ?? 0
                    let strokeMaxX = points.map { $0.x }.max() ?? 0
                    let strokeMinY = points.map { $0.y }.min() ?? 0
                    let strokeMaxY = points.map { $0.y }.max() ?? 0
                    let rect = CGRect(x: strokeMinX, y: strokeMinY, width: strokeMaxX - strokeMinX, height: strokeMaxY - strokeMinY)
                    
                    // A. Phát hiện Run tay (Tremor Index) 🟣
                    if stroke.tremorIndex > 5.0 {
                        var tremorPath = Path()
                        tremorPath.move(to: CGPoint(x: points[0].x, y: points[0].y))
                        for i in 1..<points.count { tremorPath.addLine(to: CGPoint(x: points[i].x, y: points[i].y)) }
                        context.stroke(tremorPath, with: .color(.purple.opacity(0.15)), lineWidth: 10) // Glow tím
                        context.draw(Text("Tremor").font(.system(size: 7, weight: .bold)).foregroundColor(.purple), at: CGPoint(x: strokeMaxX, y: strokeMaxY + 4))
                    }
                    
                    // B. Phát hiện LệCH DÒNG (Baseline Drift) 🔴
                    if let b = stroke.baselineY, avgBaselineY > 0, abs(b - avgBaselineY) > 15 {
                        let driftColor = b > avgBaselineY ? Color.red : Color.blue // Rớt dòng (red) vs Bay lên (blue)
                        context.stroke(Path { p in
                            p.move(to: CGPoint(x: strokeMinX, y: b))
                            p.addLine(to: CGPoint(x: strokeMaxX, y: b))
                        }, with: .color(driftColor.opacity(0.5)), lineWidth: 2)
                    }
                    
                    // C. Phân tích Kích thước & Khoảng cách (Đã có từ v1.0)
                    if let h = stroke.height, avgHeight > 0, (h > avgHeight * 1.4 || h < avgHeight * 0.6) {
                        context.stroke(Path(roundedRect: rect.insetBy(dx: -2, dy: -2), cornerRadius: 2), with: .color(.red.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                    
                    if let s = stroke.spacingToPrevious, avgSpacing > 0, (s > avgSpacing * 1.8 || s < avgSpacing * 0.3) {
                        let gapRect = CGRect(x: strokeMinX - CGFloat(s), y: strokeMaxY, width: CGFloat(s), height: 3)
                        context.fill(Path(gapRect), with: .color(.orange.opacity(0.4)))
                    }
                    
                    // D. Phân tích Từng Điểm (Áp lực & Do dự) 🔵⚪🟡
                    for point in points {
                        // Áp lực bút (Force) - Vẽ shadow dưới nét bút
                        if point.force > 0.8 { // Heavy
                            context.fill(Path(ellipseIn: CGRect(x: point.x-2, y: point.y+2, width: 4, height: 4)), with: .color(.blue.opacity(0.2)))
                        } else if point.force < 0.1 { // Ghost
                            context.fill(Path(ellipseIn: CGRect(x: point.x-2, y: point.y+2, width: 4, height: 4)), with: .color(.gray.opacity(0.2)))
                        }
                        
                        // Do dự (Hesitation/Slow) - Chấm vàng
                        if let s = point.speed, s < 150 && s > 0 {
                            context.fill(Path(ellipseIn: CGRect(x: point.x-1, y: point.y-1, width: 2, height: 2)), with: .color(.yellow.opacity(0.8)))
                        }
                    }
                }
            }
            
            // Chỉ báo điểm Mới nhất (ngòi bút)
            if let activePoint = latestPoint, (currentTime - activePoint.timeOffset) < 1.0 {
                drawPenIndicator(context: context, point: activePoint)
            }
        }
        .background(NotebookBackground()) // Ốp Vở kẻ 4 ô ly làm nền
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
