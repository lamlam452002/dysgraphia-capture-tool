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
        if let session = session {
            ExportManager.saveSession(session)
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
            Path { path in
                let spacing: CGFloat = 45
                let verticalMargin: CGFloat = 60
                
                // Dòng kẻ ngang
                for y in stride(from: verticalMargin, to: geo.size.height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(Color.blue.opacity(0.15), lineWidth: 1)
            
            // Đường lề đỏ
            Path { path in
                path.move(to: CGPoint(x: 80, y: 0))
                path.addLine(to: CGPoint(x: 80, y: geo.size.height))
            }
            .stroke(Color.red.opacity(0.3), lineWidth: 2)
        }
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
