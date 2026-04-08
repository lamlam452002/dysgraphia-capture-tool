import SwiftUI
import PencilKit

struct DrawingView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var session: HandwritingSession?
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.delegate = context.coordinator
        
        // Cài đặt PencilKit để nhận dữ liệu thô nhạy hơn
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        
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
        
        init(_ parent: DrawingView) {
            self.parent = parent
        }
        
        func resetIndex() {
            lastProcessedStrokeIndex = -1
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
                        let processedStroke = DataProcessor.process(pkStroke: pkStroke, sessionStartTime: session.timestamp)
                        
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
