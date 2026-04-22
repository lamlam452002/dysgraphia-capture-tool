import SwiftUI
import PencilKit

struct DrawingView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var session: HandwritingSession?
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .pencilOnly
        canvasView.delegate = context.coordinator
        
        // Cài đặt PencilKit để nhận dữ liệu thô nhạy hơn
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        
        // QUAN TRỌNG: Ép buộc giao diện sáng để mực Đen không bị biến thành Trắng khi iPad ở Dark Mode
        canvasView.overrideUserInterfaceStyle = .light
        
        // Mặc định luôn là bút mực đen để đồng bộ với giấy ô ly
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 2)
        
        // Cấu hình ToolPicker
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        
        // Cập nhật tool picker nếu cần
        if uiView.drawing.strokes.isEmpty && session?.strokes.isEmpty == true {
             context.coordinator.resetIndex()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingView
        private var lastProcessedStrokeIndex = -1
        
        private var calculatedIdleGap: TimeInterval = 0
        
        init(_ parent: DrawingView) {
            self.parent = parent
        }
        
        func resetIndex() {
            lastProcessedStrokeIndex = -1
            calculatedIdleGap = 0
        }
        
        /// Được gọi bất cứ khi nào bản vẽ thay đổi (thêm nét mới)
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let drawing = canvasView.drawing
            let strokes = drawing.strokes
            
            // Xử lý các nét vẽ mới chưa được ghi nhận
            if strokes.count > lastProcessedStrokeIndex + 1 {
                for i in (lastProcessedStrokeIndex + 1)..<strokes.count {
                    let pkStroke = strokes[i]
                    
                    if let session = parent.session {
                        // Tính chính xác thời gian chờ (Idle Gap) ngay tại thời điểm nét đầu tiên vừa vẽ xong
                        if i == 0 {
                            let durationOfFirstStroke = pkStroke.path.map { $0.timeOffset }.max() ?? 0
                            let approximateTouchDownDate = Date().addingTimeInterval(-durationOfFirstStroke)
                            calculatedIdleGap = max(0, approximateTouchDownDate.timeIntervalSince(session.timestamp))
                        }
                        
                        let baseCreationDate = strokes.first?.path.creationDate ?? Date()
                        // Truyền nét đằng trước vào để tính toán khoảng cách (Spacing Gap)
                        let previousStroke = parent.session?.strokes.last
                        let processedStroke = DataProcessor.process(pkStroke: pkStroke, baseCreationDate: baseCreationDate, idleGap: calculatedIdleGap, previousStroke: previousStroke)
                        
                        // Cập nhật session
                        DispatchQueue.main.async {
                            self.parent.session?.strokes.append(processedStroke)
                            print("Stroke processed: \(processedStroke.points.count) points, Speed: \(processedStroke.averageSpeed)")
                        }
                    }
                }
                lastProcessedStrokeIndex = strokes.count - 1
            }
        }
    }
}
