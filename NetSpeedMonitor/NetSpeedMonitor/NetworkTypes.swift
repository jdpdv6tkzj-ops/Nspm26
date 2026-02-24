import Cocoa

enum NetworkConnectionType: String {
    case wifi = "Wi-Fi"
    case ethernet = "Ethernet"
    case bluetooth = "Bluetooth"
    case other = "Other"
}

struct NetworkInterface {
    var status: Bool = false
    var displayName: String = ""
    var bsdName: String = ""
    var address: String = ""
    var transmitRate: Double = 0
}

struct NetworkAddress {
    var ipv4: String?
    var ipv6: String?
}

struct WiFiDetails {
    var ssid: String?
    var bssid: String?
    var countryCode: String?
    var rssi: Int?
    var noise: Int?
    var standard: String?
    var channel: String?
}

struct Bandwidth {
    var upload: Int64 = 0
    var download: Int64 = 0
}

struct NetworkUsage {
    var bandwidth: Bandwidth = Bandwidth()
    var total: Bandwidth = Bandwidth()
    var localAddress: NetworkAddress = NetworkAddress()
    var interface: NetworkInterface?
    var connectionType: NetworkConnectionType?
    var status: Bool = false
    var wifiDetails: WiFiDetails = WiFiDetails()
    
    mutating func reset() {
        self.bandwidth = Bandwidth()
        self.localAddress = NetworkAddress()
        self.interface = nil
        self.connectionType = nil
        self.wifiDetails = WiFiDetails()
    }
}

struct NetworkProcess {
    var pid: Int
    var name: String
    var time: Date
    var download: Int
    var upload: Int
    
    var icon: NSImage? {
        if let app = NSRunningApplication(processIdentifier: pid_t(self.pid)), let icon = app.icon {
            return icon
        }
        if #available(macOS 11.0, *) {
            return NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
        }
        return NSImage(named: NSImage.applicationIconName)
    }
    
    init(pid: Int = 0, name: String = "", time: Date = Date(), download: Int = 0, upload: Int = 0) {
        self.pid = pid
        self.name = name
        self.time = time
        self.download = download
        self.upload = upload
    }
}
