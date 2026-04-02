import Foundation
import SwiftUI

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"
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
    
    @discardableResult
    static func exportSession(_ session: HandwritingSession, format: ExportFormat) -> URL? {
        switch format {
        case .csv:
            return exportToCSV(session)
        case .json:
            return exportToJSON(session)
        }
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
        var csvString = "Timestamp,SessionID,StudentID,StrokeID,PointTimeOffset,X,Y,Force,Azimuth,Altitude,Speed,IsReviewed,Legibility,Spacing,Consistency,Alignment,PressureLabel,Notes\n"
        
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
