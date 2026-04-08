import SwiftUI
import PencilKit
import LocalAuthentication

struct ContentView: View {
    @State private var studentID: String = ""
    @State private var isDrawingActive = false
    @State private var isReviewActive = false
    @State private var canvasView = PKCanvasView()
    @State private var currentSession: HandwritingSession?
    
    @State private var showAuthAlert = false
    @State private var authError: String?
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header Section
                    VStack(spacing: 8) {
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        Text("DysgraphiaCollect")
                            .font(.largeTitle.bold())
                        Text("Handwriting Data Capture & Analysis")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Action Cards
                    VStack(spacing: 16) {
                        // 1. Capture Data Card
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Data Collection", systemImage: "hand.draw.fill")
                                .font(.headline)
                            
                            TextField("Enter Student ID", text: $studentID)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .padding(.vertical, 4)
                            
                            Button(action: startCapture) {
                                Text("Start New Session")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(studentID.isEmpty ? Color.gray : Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .disabled(studentID.isEmpty)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 10)
                        
                        // 2. Expert Review Card
                        Button(action: authenticateExpert) {
                            HStack {
                                Image(systemName: "person.badge.shield.checkmark.fill")
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text("Expert Review Mode")
                                        .font(.headline)
                                    Text("Labeling and session analysis")
                                        .font(.caption)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(16)
                        }
                        
                        Divider().padding(.vertical)
                        
                        // Recent Stats or Info
                        HStack(spacing: 20) {
                            MetricCard(title: "Status", value: "Ready", icon: "checkmark.circle.fill", color: .green)
                            MetricCard(title: "Version", value: "1.0.0", icon: "sparkles", color: .purple)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationDestination(isPresented: $isDrawingActive) {
                CaptureView(studentID: studentID, canvasView: $canvasView, session: $currentSession)
            }
            .fullScreenCover(isPresented: $isReviewActive) {
                ExpertReviewView()
            }
            .alert("Access Denied", isPresented: $showAuthAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authError ?? "Authentication required.")
            }
        }
    }
    
    private func startCapture() {
        // Clear previous drawing on the literal canvas
        canvasView.drawing = PKDrawing()
        
        // Initialize new session
        currentSession = HandwritingSession(studentID: studentID, strokes: [])
        isDrawingActive = true
    }
    
    private func authenticateExpert() {
        let context = LAContext()
        var error: NSError?
        
        // Dùng .deviceOwnerAuthentication sẽ TỰ ĐỘNG yêu cầu MẬT KHẨU IPAD nếu Face ID/Touch ID thất bại!
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Biometric / Device Passcode Authentication"
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        self.isReviewActive = true
                    } else {
                        self.authError = authError?.localizedDescription ?? "Authentication failed."
                        self.showAuthAlert = true
                    }
                }
            }
        } else {
            self.authError = "Tùy chọn bảo mật không có sẵn. Vui lòng cài passcode hoặc FaceID cho iPad."
            self.showAuthAlert = true
        }
    }
}

struct CaptureView: View {
    let studentID: String
    @Binding var canvasView: PKCanvasView
    @Binding var session: HandwritingSession?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Capture: \(studentID)")
                        .font(.headline)
                    Text("Pencil Data actively streaming...")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
                Button("Finish & Save") {
                    saveSession()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.thinMaterial)
            
            ZStack {
                NotebookBackground()
                DrawingView(canvasView: $canvasView, session: $session)
            }
        }
        .navigationBarHidden(true)
    }
    
    private func saveSession() {
        // Chỉ tiến hành quy trình lưu file khi Session tồn tại và có chứa ít nhất 1 nét vẽ
        if let session = session, !session.strokes.isEmpty {
            ExportManager.saveSession(session)
        } else {
            print("Đã hủy bỏ Session trống (không có nét vẽ nào).")
        }
        dismiss()
    }
}

// MARK: - Premium Components

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(color.gradient)
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline.monospacedDigit())
            }
        }
        .padding(.vertical, 4)
    }
}

struct NotebookBackground: View {
    var body: some View {
        GeometryReader { geo in
            let gridSize: CGFloat = 16 // Kích thước 1 ô ly con
            let majorGridSpacing: CGFloat = gridSize * 5 // 5 ô ly con gộp thành 1 khối ô vuông lớn (Vở 5 ô ly)
            
            // Màu mực in trên giấy (Xanh lơ Cyan chuẩn vở Việt Nam)
            let inkColor = Color(red: 0.0, green: 0.6, blue: 0.8)
            
            // 1. Mạch kẻ mờ (Các dòng kẻ con nằm bên trong)
            Path { path in
                for y in stride(from: 0, to: geo.size.height, by: gridSize) {
                    if y.truncatingRemainder(dividingBy: majorGridSpacing) != 0 {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                for x in stride(from: 0, to: geo.size.width, by: gridSize) {
                    if x.truncatingRemainder(dividingBy: majorGridSpacing) != 0 {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                }
            }
            .stroke(inkColor.opacity(0.2), lineWidth: 0.5) // Nét cực mảnh
            
            // 2. Mạch kẻ đậm (Các đường viền khung lớn)
            Path { path in
                for y in stride(from: 0, to: geo.size.height, by: majorGridSpacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
                for x in stride(from: 0, to: geo.size.width, by: majorGridSpacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
            }
            .stroke(inkColor.opacity(0.4), lineWidth: 1.2) // Nét đậm nhưng không gắt
            
            // 3. Đường lề đỏ (Cột lề lùi vào 1 khối lớn rưỡi hoặc 2 khối)
            Path { path in
                let marginX = majorGridSpacing * 1.5
                path.move(to: CGPoint(x: marginX, y: 0))
                path.addLine(to: CGPoint(x: marginX, y: geo.size.height))
            }
            .stroke(Color.red.opacity(0.4), lineWidth: 1.5)
        }
        .background(Color.white) // Giấy luôn trắng
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // Hỗ trợ iPad Popover
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView() // Dummy view for source
            // Tốt hơn là nhận sourceView từ SwiftUI, nhưng sheet thường tự xử lý
            // nếu được gọi từ .sheet
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
