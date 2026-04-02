import SwiftUI
import PencilKit

struct ContentView: View {
    @State private var canvasView = PKCanvasView()
    @State private var session: HandwritingSession? = HandwritingSession(studentID: "HS001", timestamp: Date())
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    
    // UI State
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: - Sidebar: Controls & Stats
            sidebarView
                .navigationTitle("Cấu hình")
        } detail: {
            // MARK: - Main Area: Drawing Canvas
            mainCanvasArea
                .navigationTitle("Vùng viết")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            Button(action: clearCanvas) {
                                Label("Xóa", systemImage: "trash")
                            }
                            .tint(.red)
                            
                            Button(action: exportCSV) {
                                Label("Xuất CSV", systemImage: "doc.text.fill")
                            }
                        }
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    // MARK: - Subviews
    
    private var sidebarView: some View {
        List {
            Section("Thông tin phiên") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mã số học sinh")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    TextField("ID", text: Binding(
                        get: { session?.studentID ?? "" },
                        set: { session?.id = UUID(); session = HandwritingSession(studentID: $0, timestamp: Date()) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                }
                .padding(.vertical, 8)
            }
            
            Section("Chỉ số đo lường") {
                MetricCard(title: "Số nét vẽ", value: "\(session?.strokes.count ?? 0)", icon: "pencil.line", color: .blue)
                MetricCard(title: "Tốc độ TB", value: String(format: "%.1f", averageSessionSpeed), icon: "speedometer", color: .orange)
                MetricCard(title: "Độ giật (Jitter)", value: String(format: "%.2f", averageSessionJitter), icon: "waveform.path.ecg", color: .purple)
            }
            
            Section("Dữ liệu") {
                Button(action: exportCSV) {
                    Label("Xuất dữ liệu CSV", systemImage: "tablecells")
                }
                
                Button(action: exportJSON) {
                    Label("Lưu phiên (JSON)", systemImage: "shippingbox")
                }
            }
        }
    }
    
    private var mainCanvasArea: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            // Lưới nền chuyên nghiệp
            NotebookBackground()
            
            DrawingView(canvasView: $canvasView, session: $session)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Logic
    
    private var averageSessionSpeed: Double {
        guard let strokes = session?.strokes, !strokes.isEmpty else { return 0 }
        return strokes.map { $0.averageSpeed }.reduce(0, +) / Double(strokes.count)
    }
    
    private var averageSessionJitter: Double {
        guard let strokes = session?.strokes, !strokes.isEmpty else { return 0 }
        return strokes.map { $0.jitterMetric }.reduce(0, +) / Double(strokes.count)
    }
    
    private func clearCanvas() {
        canvasView.drawing = PKDrawing()
        session?.strokes = []
    }
    
    private func exportCSV() {
        if let s = session {
            exportURL = ExportManager.exportToCSV(session: s)
            showExportSheet = true
        }
    }
    
    private func exportJSON() {
        if let s = session {
            exportURL = ExportManager.exportToJSON(session: s)
            showExportSheet = true
        }
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
