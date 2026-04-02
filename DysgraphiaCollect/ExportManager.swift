import Foundation

class ExportManager {
    
    /// Xuất dữ liệu sang định dạng JSON
    static func exportToJSON(session: HandwritingSession) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(session)
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(session.fileName).json")
            try data.write(to: fileURL)
            print("Successfully exported JSON to: \(fileURL.path)")
            return fileURL
        } catch {
            print("Lỗi khi xuất JSON: \(error)")
            return nil
        }
    }
    
    /// Xuất dữ liệu sang định dạng CSV (Chi tiết từng điểm vẽ)
    static func exportToCSV(session: HandwritingSession) -> URL? {
        var csvString = "StrokeID,PointID,X,Y,TimeOffset,Force,Azimuth,Altitude,Speed\n"
        
        for stroke in session.strokes {
            for (index, point) in stroke.points.enumerated() {
                let line = "\(stroke.id.uuidString),\(index),\(point.x),\(point.y),\(point.timeOffset),\(point.force),\(point.azimuth),\(point.altitude),\(point.speed ?? 0)\n"
                csvString.append(line)
            }
        }
        
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(session.fileName).csv")
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully exported CSV to: \(fileURL.path)")
            return fileURL
        } catch {
            print("Lỗi khi xuất CSV: \(error)")
            return nil
        }
    }
}
