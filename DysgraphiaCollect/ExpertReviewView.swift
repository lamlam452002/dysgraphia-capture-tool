import SwiftUI
import Combine

// MARK: - ViewModel

final class ReviewViewModel: ObservableObject {
    @Published var sessions: [HandwritingSession] = []
    @Published var deletedSessions: [HandwritingSession] = []
    @Published var selectedSession: HandwritingSession?
    @Published var currentTime: TimeInterval = 0
    @Published var isPlaying = false
    @Published var playbackSpeed: Double = 1.0
    
    // Trạng thái chưa lưu
    @Published var hasUnsavedChanges: Bool = false
    @Published var selectedExportFormat: ExportFormat = .csv
    @Published var showExportSuccess = false
    @Published var exportedURL: URL?
    
    // Rename state
    @Published var folderToRename: String = ""
    @Published var renameText: String = ""
    @Published var showRenameAlert = false
    
    private var timer: Timer?
    
    // MARK: - Computed Properties
    
    /// Nhóm sessions theo studentID thành "Folders" giống Notes app
    var studentFolders: [(studentID: String, count: Int)] {
        let grouped = Dictionary(grouping: sessions, by: { $0.studentID })
        return grouped.map { (studentID: $0.key, count: $0.value.count) }
            .sorted(by: { $0.studentID.localizedCaseInsensitiveCompare($1.studentID) == .orderedAscending })
    }
    
    func sessionsForStudent(_ studentID: String) -> [HandwritingSession] {
        sessions.filter { $0.studentID == studentID }
            .sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    var maxTime: TimeInterval {
        guard let session = selectedSession else { return 0 }
        return session.strokes.flatMap { $0.points }.map { $0.timeOffset }.max() ?? 0
    }
    
    // MARK: - Data Loading
    
    func loadSessions() {
        self.sessions = ExportManager.loadAllSessions()
        self.deletedSessions = ExportManager.loadDeletedSessions()
    }
    
    // MARK: - Playback
    
    func togglePlayback() {
        isPlaying ? stopPlayback() : startPlayback()
    }
    
    func startPlayback() {
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let step = 0.05 * self.playbackSpeed
            if self.currentTime + step < self.maxTime {
                self.currentTime += step
            } else {
                self.currentTime = self.maxTime
                self.stopPlayback()
            }
        }
    }
    
    func stopPlayback() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
    }
    
    // MARK: - Save & Export
    
    func saveProgress(annotation: ReviewAnnotation) {
        guard var session = selectedSession else { return }
        session.annotation = annotation
        ExportManager.saveSession(session)
        self.selectedSession = session
        self.hasUnsavedChanges = false
        loadSessions()
    }
    
    func exportData(annotation: ReviewAnnotation) {
        guard var session = selectedSession else { return }
        session.annotation = annotation
        ExportManager.saveSession(session)
        if let url = ExportManager.exportSession(session, format: selectedExportFormat) {
            self.exportedURL = url
            self.showExportSuccess = true
        }
        self.hasUnsavedChanges = false
        loadSessions()
    }
    
    // MARK: - Folder Operations (Student-level)
    
    func beginRenameFolder(_ studentID: String) {
        folderToRename = studentID
        renameText = studentID
        showRenameAlert = true
    }
    
    func confirmRenameFolder() {
        let newID = renameText.trimmingCharacters(in: .whitespaces)
        guard !newID.isEmpty else { return }
        ExportManager.renameStudentSessions(oldID: folderToRename, newID: newID)
        if selectedSession?.studentID == folderToRename {
            selectedSession = nil
        }
        loadSessions()
    }
    
    func deleteFolderSessions(_ studentID: String) {
        for session in sessionsForStudent(studentID) {
            ExportManager.moveToTrash(session)
        }
        if selectedSession?.studentID == studentID {
            selectedSession = nil
        }
        loadSessions()
    }
    
    // MARK: - Session Operations
    
    func moveSessionToTrash(_ session: HandwritingSession) {
        ExportManager.moveToTrash(session)
        if selectedSession?.id == session.id { selectedSession = nil }
        loadSessions()
    }
    
    func restoreSession(_ session: HandwritingSession) {
        ExportManager.restoreFromTrash(session)
        loadSessions()
    }
    
    func permanentlyDeleteSession(_ session: HandwritingSession) {
        ExportManager.permanentlyDelete(session)
        loadSessions()
    }
    
    func emptyTrash() {
        ExportManager.emptyTrash()
        loadSessions()
    }
}

// MARK: - Main Container

struct ExpertReviewView: View {
    @StateObject private var viewModel = ReviewViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showExitConfirmation = false
    @State private var folderToDelete: String?
    @State private var showDeleteFolderAlert = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: viewModel,
                onBack: {
                    if viewModel.hasUnsavedChanges {
                        showExitConfirmation = true
                    } else {
                        dismiss()
                    }
                },
                onDeleteFolder: { studentID in
                    folderToDelete = studentID
                    showDeleteFolderAlert = true
                }
            )
        } detail: {
            if let session = viewModel.selectedSession {
                ReviewDetailView(session: session, viewModel: viewModel)
                    .id(session.id)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select Session")
                        .font(.title2.bold())
                    Text("Choose a session from the sidebar to begin expert labeling.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        // Alert: Xác nhận thoát
        .alert("Unsaved Changes", isPresented: $showExitConfirmation) {
            Button("Discard", role: .destructive) {
                viewModel.hasUnsavedChanges = false
                dismiss()
            }
            Button("No", role: .cancel) {}
        } message: {
            Text("Bạn có thay đổi chưa lưu. Bạn có muốn huỷ bỏ không?")
        }
        // Alert: Xác nhận xoá folder
        .alert("Delete Folder?", isPresented: $showDeleteFolderAlert) {
            Button("Delete", role: .destructive) {
                if let id = folderToDelete {
                    viewModel.deleteFolderSessions(id)
                }
                folderToDelete = nil
            }
            Button("Cancel", role: .cancel) { folderToDelete = nil }
        } message: {
            if let id = folderToDelete {
                Text("Chuyển tất cả session của \"\(id)\" vào thùng rác?")
            }
        }
        // Alert: Đổi tên folder
        .alert("Rename", isPresented: $viewModel.showRenameAlert) {
            TextField("Student ID", text: $viewModel.renameText)
            Button("Rename") { viewModel.confirmRenameFolder() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Nhập tên mới cho \"\(viewModel.folderToRename)\":")
        }
        // Sheet: Chia sẻ file xuất
        .sheet(isPresented: $viewModel.showExportSuccess) {
            if let url = viewModel.exportedURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
}

// MARK: - Sidebar (Notes-style folder list)

struct SidebarView: View {
    @ObservedObject var viewModel: ReviewViewModel
    var onBack: () -> Void
    var onDeleteFolder: (String) -> Void
    
    @State private var sidebarPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $sidebarPath) {
            List {
                // Folders (nhóm theo studentID)
                Section {
                    ForEach(viewModel.studentFolders, id: \.studentID) { folder in
                        NavigationLink(value: folder.studentID) {
                            FolderRow(
                                name: folder.studentID,
                                count: folder.count,
                                onRename: { viewModel.beginRenameFolder(folder.studentID) },
                                onDelete: { onDeleteFolder(folder.studentID) }
                            )
                        }
                    }
                }
                
                // Thùng rác (Recently Deleted)
                Section {
                    NavigationLink(value: "__trash__") {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.gray)
                                .font(.title3)
                                .frame(width: 28)
                            Text("Recently Deleted")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(viewModel.deletedSessions.count)")
                                .foregroundColor(.secondary)
                                .font(.callout)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Data Review")
            .onAppear { viewModel.loadSessions() }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                            Text("Back")
                        }
                        .foregroundColor(.accentColor)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.loadSessions) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .navigationDestination(for: String.self) { value in
                if value == "__trash__" {
                    TrashSessionListView(viewModel: viewModel)
                } else {
                    StudentSessionListView(studentID: value, viewModel: viewModel)
                }
            }
        }
    }
}

// MARK: - Folder Row (giống Notes app: icon folder vàng + tên + count + "..." menu)

struct FolderRow: View {
    let name: String
    let count: Int
    var onRename: () -> Void
    var onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.yellow)
                .font(.title3)
                .frame(width: 28)
            
            Text(name)
                .lineLimit(1)
            
            Spacer()
            
            // "..." menu — hiển thị khi hover hoặc luôn hiện nhẹ
            Menu {
                Button { onRename() } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(isHovered ? .primary : .secondary.opacity(0.5))
                    .font(.body)
            }
            .buttonStyle(.plain)
            
            Text("\(count)")
                .foregroundColor(.secondary)
                .font(.callout)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Session List for a Student (bên trong một folder)

struct StudentSessionListView: View {
    let studentID: String
    @ObservedObject var viewModel: ReviewViewModel
    @State private var sessionToDelete: HandwritingSession?
    @State private var showDeleteAlert = false
    
    var sessions: [HandwritingSession] {
        viewModel.sessionsForStudent(studentID)
    }
    
    var body: some View {
        List(sessions, selection: $viewModel.selectedSession) { session in
            SessionRow(session: session)
                .tag(session)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        sessionToDelete = session
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        sessionToDelete = session
                        showDeleteAlert = true
                    } label: {
                        Label("Move to Trash", systemImage: "trash")
                    }
                }
        }
        .navigationTitle(studentID)
        .alert("Delete Session?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let s = sessionToDelete { viewModel.moveSessionToTrash(s) }
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
        } message: {
            Text("Chuyển session này vào thùng rác?")
        }
    }
}

// MARK: - Trash Session List (Recently Deleted)

struct TrashSessionListView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @State private var showEmptyTrashAlert = false
    
    var body: some View {
        Group {
            if viewModel.deletedSessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "trash.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Thùng rác trống")
                        .font(.title3.bold())
                    Text("Các session đã xoá sẽ hiển thị ở đây.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.deletedSessions) { session in
                        HStack(spacing: 12) {
                            // Icon trạng thái
                            Image(systemName: "doc.text")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            
                            // Thông tin session
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.studentID)
                                    .font(.subheadline.bold())
                                HStack(spacing: 4) {
                                    Text(session.timestamp, style: .date)
                                    Text("·")
                                    Text(session.timestamp, style: .time)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Nút Restore rõ ràng
                            Button {
                                withAnimation { viewModel.restoreSession(session) }
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.permanentlyDeleteSession(session)
                            } label: {
                                Label("Delete Forever", systemImage: "xmark.bin")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                viewModel.restoreSession(session)
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .toolbar {
            if !viewModel.deletedSessions.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            for session in viewModel.deletedSessions {
                                viewModel.restoreSession(session)
                            }
                        } label: {
                            Label("Restore All", systemImage: "arrow.uturn.backward")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showEmptyTrashAlert = true
                        } label: {
                            Label("Empty Trash", systemImage: "trash.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Empty Trash?", isPresented: $showEmptyTrashAlert) {
            Button("Delete All", role: .destructive) { viewModel.emptyTrash() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Xoá vĩnh viễn \(viewModel.deletedSessions.count) session? Hành động này không thể hoàn tác.")
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: HandwritingSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.timestamp, style: .date)
                Text(session.timestamp, style: .time)
            }
            .font(.subheadline)
            
            HStack(spacing: 6) {
                Text("\(session.strokes.count) strokes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if session.annotation.isReviewed {
                    Label("Reviewed", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Review Detail View

struct ReviewDetailView: View {
    let session: HandwritingSession
    @ObservedObject var viewModel: ReviewViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Playback Header
            HStack(spacing: 16) {
                // Play / Pause
                Button(action: viewModel.togglePlayback) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // Timeline
                VStack(spacing: 6) {
                    Slider(value: $viewModel.currentTime, in: 0...max(0.1, viewModel.maxTime))
                        .tint(.blue)
                    HStack {
                        Text(String(format: "%.1fs", viewModel.currentTime))
                        Spacer()
                        Text(String(format: "%.1fs", viewModel.maxTime))
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                }
                
                // Speed Selector — pill tối giản
                HStack(spacing: 0) {
                    ForEach([0.5, 1.0, 2.0], id: \.self) { speed in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.playbackSpeed = speed
                            }
                        } label: {
                            Text(speed == 1.0 ? "1×" : (speed == 0.5 ? "½×" : "2×"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .frame(width: 36, height: 28)
                                .foregroundColor(viewModel.playbackSpeed == speed ? .white : .secondary)
                                .background(
                                    viewModel.playbackSpeed == speed
                                    ? Color.blue
                                    : Color.clear
                                )
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color(uiColor: .tertiarySystemFill))
                .cornerRadius(9)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemBackground))
            
            // Main content split
            HStack(spacing: 0) {
                VStack {
                    PlaybackCanvas(session: session, currentTime: $viewModel.currentTime)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 10)
                        .padding()
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SectionHeader(title: "Handwriting Telemetry")
                        TelemetryChartView(session: session, currentTime: $viewModel.currentTime)
                            .frame(height: 450)
                        
                        Divider()
                        
                        SectionHeader(title: "Expert Labeling (Level 0-5)")
                        AnnotationFormView(session: session, viewModel: viewModel)
                    }
                    .padding()
                }
                .frame(width: 400)
            }
        }
        .navigationTitle("Analysis: \(session.studentID)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.bold())
            .foregroundColor(.secondary)
            .tracking(1)
    }
}

// MARK: - Annotation Form (Reviewed/Unreviewed toggle + Export)

struct AnnotationFormView: View {
    @State var annotation: ReviewAnnotation
    @ObservedObject var viewModel: ReviewViewModel
    
    init(session: HandwritingSession, viewModel: ReviewViewModel) {
        self._annotation = State(initialValue: session.annotation)
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Score rows
            VStack(spacing: 12) {
                ScoreRow(label: "Legibility", description: "Khả năng đọc", value: $annotation.legibilityScore)
                ScoreRow(label: "Spacing", description: "Khoảng cách", value: $annotation.spacingScore)
                ScoreRow(label: "Consistency", description: "Kích thước biến thiên", value: $annotation.sizeConsistencyScore)
                ScoreRow(label: "Alignment", description: "Căn hàng", value: $annotation.lineAlignmentScore)
                ScoreRow(label: "Pressure", description: "Lực nhấn phù hợp", value: $annotation.pressureScore)
            }
            .onChange(of: annotation.legibilityScore) { _ in viewModel.hasUnsavedChanges = true }
            .onChange(of: annotation.spacingScore) { _ in viewModel.hasUnsavedChanges = true }
            .onChange(of: annotation.sizeConsistencyScore) { _ in viewModel.hasUnsavedChanges = true }
            .onChange(of: annotation.lineAlignmentScore) { _ in viewModel.hasUnsavedChanges = true }
            .onChange(of: annotation.pressureScore) { _ in viewModel.hasUnsavedChanges = true }
            
            // Notes
            VStack(alignment: .leading) {
                Text("Notes (Ghi chú chuyên môn)")
                    .font(.subheadline.bold())
                TextEditor(text: $annotation.notes)
                    .frame(height: 100)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2)))
                    .onChange(of: annotation.notes) { _ in viewModel.hasUnsavedChanges = true }
            }
            
            Divider()
            
            // Export Format Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Export Format")
                    .font(.caption.bold())
                Picker("Format", selection: $viewModel.selectedExportFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                // Reviewed / Unreviewed toggle
                Button(action: {
                    annotation.isReviewed.toggle()
                    viewModel.saveProgress(annotation: annotation)
                }) {
                    Label(
                        annotation.isReviewed ? "Unreviewed" : "Reviewed",
                        systemImage: annotation.isReviewed ? "xmark.circle" : "checkmark.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(annotation.isReviewed ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // Export button
                Button(action: { viewModel.exportData(annotation: annotation) }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - Score Row

struct ScoreRow: View {
    let label: String
    let description: String
    @Binding var value: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(value)")
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundColor(.blue)
            }
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Picker(label, selection: $value) {
                ForEach(0...5, id: \.self) { i in
                    Text("\(i)").tag(i)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
