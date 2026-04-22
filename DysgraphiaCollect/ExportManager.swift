import Foundation
import SwiftUI
import AVFoundation
import CoreImage

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"
    case bundle = "Full Session"
    var id: String { self.rawValue }
}

class ExportManager {
    
    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private static var sessionsDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("sessions", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    // MARK: - JSON Persistence (Lưu nội bộ)
    
    static func saveSession(_ session: HandwritingSession) {
        let fileURL = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted // Dễ đọc hơn cho chuyên gia
        
        do {
            let data = try encoder.encode(session)
            try data.write(to: fileURL)
            print("Session saved locally: \(fileURL.path)")
        } catch {
            print("Error saving session: \(error)")
        }
    }
    
    static func loadAllSessions() -> [HandwritingSession] {
        do {
            if !FileManager.default.fileExists(atPath: sessionsDirectory.path) {
                return []
            }
            let files = try FileManager.default.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sessions = files.compactMap { url -> HandwritingSession? in
                guard url.pathExtension == "json" else { return nil }
                do {
                    let data = try Data(contentsOf: url)
                    return try decoder.decode(HandwritingSession.self, from: data)
                } catch {
                    print("Error loading session at \(url): \(error)")
                    return nil
                }
            }
            return sessions.sorted(by: { $0.timestamp > $1.timestamp })
        } catch {
            print("Error listing sessions: \(error)")
            return []
        }
    }
    
    // MARK: - Export (Xuất file theo yêu cầu)
    
    @MainActor
    @discardableResult
    static func exportSessionAsync(_ session: HandwritingSession, format: ExportFormat, showAnalysis: Bool = false) async -> URL? {
        switch format {
        case .csv:
            return exportToCSV(session)
        case .json:
            return exportToJSON(session)
        case .bundle:
            return await exportToBundleAsync(session, showAnalysis: showAnalysis)
        }
    }
    
    @MainActor
    private static func exportToBundleAsync(_ session: HandwritingSession, showAnalysis: Bool) async -> URL? {
        let bundleName = "dysgraphia_\(session.studentID)_\(session.id.uuidString.prefix(6))"
        let bundleURL = FileManager.default.temporaryDirectory.appendingPathComponent(bundleName, isDirectory: true)
        
        do {
            if FileManager.default.fileExists(atPath: bundleURL.path) {
                try FileManager.default.removeItem(at: bundleURL)
            }
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
            
            // 1. JSON
            if let jsonURL = exportToJSON(session) {
                let dest = bundleURL.appendingPathComponent(jsonURL.lastPathComponent)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: jsonURL, to: dest)
            }
            
            // 2. CSV
            if let csvURL = exportToCSV(session) {
                let dest = bundleURL.appendingPathComponent(csvURL.lastPathComponent)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: csvURL, to: dest)
            }
            
            // 3. PNG Image Render
            // Cuộn thời gian đến khi kết thúc nét vẽ cuối cùng
            let maxTime = session.strokes.flatMap { $0.points }.map { $0.timeOffset }.max() ?? 0
            
            // Dựng lại khung hình Landscape iPad để chụp tĩnh (4:3)
            let captureFrame = ZStack {
                NotebookBackground()
                PlaybackCanvas(session: session, currentTime: .constant(maxTime + 1.0), showAnalysis: showAnalysis)
            }.frame(width: 1080, height: 810)
            
            let renderer = ImageRenderer(content: captureFrame)
            renderer.scale = 2.0 // Gấp đôi độ phân giải ảnh (Retina)
            
            if let image = renderer.uiImage, let data = image.pngData() {
                let pngURL = bundleURL.appendingPathComponent("\(bundleName)_handwriting.png")
                try data.write(to: pngURL)
            }
            
            // 4. PNG Image Render cho TelemetryChart
            let chartFrame = TelemetryChartContent(session: session, currentTime: .constant(maxTime + 1.0))
                .padding()
                .background(Color.white) // Nền trắng để tránh ảnh bị trong suốt/đen
                .frame(width: 1080, height: 1400) // Chiều cao lớn hơn để hiển thị hết các biểu đồ
            let chartRenderer = ImageRenderer(content: chartFrame)
            chartRenderer.scale = 2.0
            if let image = chartRenderer.uiImage, let data = image.pngData() {
                let chartURL = bundleURL.appendingPathComponent("\(bundleName)_chart.png")
                try data.write(to: chartURL)
            }
            
            // 5. Video (MP4) Render cho PlaybackCanvas
            let videoURL = bundleURL.appendingPathComponent("\(bundleName)_video.mp4")
            try? await createVideo(session: session, maxTime: maxTime + 1.0, destURL: videoURL, showAnalysis: showAnalysis)
            
            return bundleURL
            
        } catch {
            print("Error creating folder bundle: \(error)")
            return nil
        }
    }
    
    @MainActor
    private static func createVideo(session: HandwritingSession, maxTime: TimeInterval, destURL: URL, showAnalysis: Bool) async throws {
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        
        guard let writer = try? AVAssetWriter(outputURL: destURL, fileType: .mp4) else { return }
        
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1080,
            AVVideoHeightKey: 810
        ]
        
        guard writer.canApply(outputSettings: settings, forMediaType: .video) else { return }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: 1080,
            kCVPixelBufferHeightKey as String: 810,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        
        guard writer.canAdd(input) else { return }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        let fps = 30.0
        let totalFrames = Int(maxTime * fps)
        let ciContext = CIContext()
        
        for frame in 0...totalFrames {
            let currentTime = Double(frame) / fps
            let captureFrame = ZStack {
                NotebookBackground()
                PlaybackCanvas(session: session, currentTime: .constant(currentTime), showAnalysis: showAnalysis)
            }.frame(width: 1080, height: 810)
            
            let renderer = ImageRenderer(content: captureFrame)
            renderer.scale = 1.0
            
            if let cgImage = renderer.cgImage, let pool = adaptor.pixelBufferPool {
                var pixelBuffer: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
                
                if let buffer = pixelBuffer {
                    CVPixelBufferLockBaseAddress(buffer, [])
                    let ciImage = CIImage(cgImage: cgImage)
                    ciContext.render(ciImage, to: buffer)
                    CVPixelBufferUnlockBaseAddress(buffer, [])
                    
                    let presentationTime = CMTimeMake(value: Int64(frame * 600), timescale: Int32(fps * 600))
                    
                    while !input.isReadyForMoreMediaData {
                        try await Task.sleep(nanoseconds: 10_000_000)
                    }
                    
                    adaptor.append(buffer, withPresentationTime: presentationTime)
                }
            }
            
            if frame % 15 == 0 {
                await Task.yield()
            }
        }
        
        input.markAsFinished()
        await writer.finishWriting()
    }
    
    private static func exportToJSON(_ session: HandwritingSession) -> URL? {
        let fileName = "dysgraphia_\(session.studentID)_\(session.id.uuidString.prefix(6)).json"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(session)
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error exporting JSON: \(error)")
            return nil
        }
    }
    
    private static func exportToCSV(_ session: HandwritingSession) -> URL? {
        var csvString = "Timestamp,SessionID,StudentID,StrokeID,PointTimeOffset,X,Y,Force,Azimuth,Altitude,Speed,TremorIndex,StrokeHeight,StrokeBaseline,StrokeSpacing,IsReviewed,Legibility,Spacing,Consistency,Alignment,PressureLabel,Notes\n"
        
        let dateFormatter = ISO8601DateFormatter()
        let timestampStr = dateFormatter.string(from: session.timestamp)
        
        for stroke in session.strokes {
            for point in stroke.points {
                let row = [
                    timestampStr,
                    session.id.uuidString,
                    session.studentID,
                    stroke.id.uuidString,
                    String(format: "%.4f", point.timeOffset),
                    String(format: "%.2f", point.x),
                    String(format: "%.2f", point.y),
                    String(format: "%.4f", point.force),
                    String(format: "%.4f", point.azimuth),
                    String(format: "%.4f", point.altitude),
                    String(format: "%.4f", point.speed ?? 0),
                    String(format: "%.4f", stroke.tremorIndex),
                    String(format: "%.2f", stroke.height ?? 0),
                    String(format: "%.2f", stroke.baselineY ?? 0),
                    String(format: "%.2f", stroke.spacingToPrevious ?? 0),
                    session.annotation.isReviewed ? "1" : "0",
                    "\(session.annotation.legibilityScore)",
                    "\(session.annotation.spacingScore)",
                    "\(session.annotation.sizeConsistencyScore)",
                    "\(session.annotation.lineAlignmentScore)",
                    "\(session.annotation.pressureScore)",
                    "\"\(session.annotation.notes.replacingOccurrences(of: "\"", with: "'"))\""
                ].joined(separator: ",")
                csvString.append(row + "\n")
            }
        }
        
        let fileName = "dysgraphia_\(session.studentID)_\(session.id.uuidString.prefix(6)).csv"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Session saved locally: \(fileURL.path)")
            return fileURL
        } catch {
            print("Error exporting CSV: \(error)")
            return nil
        }
    }
    
    // MARK: - Session Management (Quản lý phiên)
    
    /// Đổi tên studentID của một phiên và lưu lại
    static func renameSession(_ session: HandwritingSession, newStudentID: String) {
        let renamed = HandwritingSession(
            id: session.id,
            studentID: newStudentID,
            timestamp: session.timestamp,
            strokes: session.strokes,
            annotation: session.annotation
        )
        saveSession(renamed)
    }
    
    /// Đổi tên tất cả session có cùng studentID
    static func renameStudentSessions(oldID: String, newID: String) {
        let sessions = loadAllSessions().filter { $0.studentID == oldID }
        for session in sessions {
            renameSession(session, newStudentID: newID)
        }
    }
    
    // MARK: - Trash Management (Thùng rác)
    
    private static var trashDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("trash", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    /// Chuyển session vào thùng rác (soft delete)
    static func moveToTrash(_ session: HandwritingSession) {
        let sourceURL = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        let destURL = trashDirectory.appendingPathComponent("\(session.id.uuidString).json")
        try? FileManager.default.moveItem(at: sourceURL, to: destURL)
    }
    
    /// Khôi phục session từ thùng rác
    static func restoreFromTrash(_ session: HandwritingSession) {
        let sourceURL = trashDirectory.appendingPathComponent("\(session.id.uuidString).json")
        let destURL = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        try? FileManager.default.moveItem(at: sourceURL, to: destURL)
    }
    
    /// Tải danh sách session đã xoá
    static func loadDeletedSessions() -> [HandwritingSession] {
        do {
            if !FileManager.default.fileExists(atPath: trashDirectory.path) { return [] }
            let files = try FileManager.default.contentsOfDirectory(at: trashDirectory, includingPropertiesForKeys: nil)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return files.compactMap { url -> HandwritingSession? in
                guard url.pathExtension == "json" else { return nil }
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(HandwritingSession.self, from: data)
            }.sorted(by: { $0.timestamp > $1.timestamp })
        } catch { return [] }
    }
    
    /// Xoá vĩnh viễn một session từ thùng rác
    static func permanentlyDelete(_ session: HandwritingSession) {
        let fileURL = trashDirectory.appendingPathComponent("\(session.id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// Làm trống thùng rác
    static func emptyTrash() {
        for session in loadDeletedSessions() {
            permanentlyDelete(session)
        }
    }
}
