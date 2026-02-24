import Cocoa

enum SpeedFormatter {
    static func formatSpeed(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
        var index = 0
        
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        
        if value >= 100 {
            return String(format: "%.0f %@", value, units[index])
        } else if value >= 10 {
            return String(format: "%.1f %@", value, units[index])
        } else {
            return String(format: "%.2f %@", value, units[index])
        }
    }
    
    static func formatSpeedShort(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
        var index = 0
        
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        
        return "\(Int(round(value))) \(units[index])"
    }
    
    static func formatTotalBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var index = 0
        
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        
        if value >= 100 {
            return String(format: "%.0f %@", value, units[index])
        } else if value >= 10 {
            return String(format: "%.1f %@", value, units[index])
        } else {
            return String(format: "%.2f %@", value, units[index])
        }
    }
}

enum ProcessNameHelper {
    static func extractProcessNameAndPid(_ processInfo: String) -> (name: String, pid: Int32?) {
        if let dotIndex = processInfo.lastIndex(of: ".") {
            let suffix = processInfo[processInfo.index(after: dotIndex)...]
            if suffix.allSatisfy({ $0.isNumber }) {
                let name = String(processInfo[..<dotIndex])
                let pid = Int32(suffix)
                return (name, pid)
            }
        }
        return (processInfo, nil)
    }
    
    static func cleanProcessName(_ name: String) -> String {
        if let dotIndex = name.lastIndex(of: ".") {
            let suffix = name[name.index(after: dotIndex)...]
            if suffix.allSatisfy({ $0.isNumber }) {
                return String(name[..<dotIndex])
            }
        }
        return name
    }
    
    static func normalizeAppName(_ processName: String) -> String {
        var name = processName
        
        for pattern in Constants.HelperPatterns.all {
            if name.lowercased().hasSuffix(pattern.lowercased()) {
                name = String(name.dropLast(pattern.count))
                break
            }
        }
        
        if let mapping = AppMapping.find(for: name) {
            return mapping.normalizedName
        }
        
        return name
    }
    
    static func isSystemProcess(_ name: String) -> Bool {
        return Constants.SystemProcesses.all.contains(name)
    }
}
