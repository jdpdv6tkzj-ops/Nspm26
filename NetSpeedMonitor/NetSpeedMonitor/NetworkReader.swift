import Cocoa
import SystemConfiguration
import CoreWLAN

extension CWPHYMode {
    var modeDescription: String {
        switch self {
        case .mode11a: return "802.11a"
        case .mode11ac: return "802.11ac"
        case .mode11b: return "802.11b"
        case .mode11g: return "802.11g"
        case .mode11n: return "802.11n"
        case .mode11ax: return "802.11ax"
        case .modeNone: return "none"
        @unknown default: return "unknown"
        }
    }
}

extension CWChannelBand {
    var bandDescription: String {
        switch self {
        case .band2GHz: return "2 GHz"
        case .band5GHz: return "5 GHz"
        case .band6GHz: return "6 GHz"
        case .bandUnknown: return "unknown"
        @unknown default: return "unknown"
        }
    }
}

class NetworkReader {
    private var primaryInterface: String {
        get {
            if let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString),
               let name = global["PrimaryInterface"] as? String {
                return name
            }
            return ""
        }
    }
    
    private var interfaceID: String = ""
    private var previousBandwidth: Bandwidth = Bandwidth()
    private var totalBandwidth: Bandwidth = Bandwidth()
    
    init() {
        interfaceID = primaryInterface
    }
    
    func readInterfaceBandwidth() -> (upload: Int64, download: Int64) {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        var totalUpload: Int64 = 0
        var totalDownload: Int64 = 0
        
        guard getifaddrs(&interfaceAddresses) == 0 else {
            return (0, 0)
        }
        
        var pointer = interfaceAddresses
        while pointer != nil {
            defer { pointer = pointer?.pointee.ifa_next }
            guard let ptr = pointer else { break }
            
            let interfaceName = String(cString: ptr.pointee.ifa_name)
            
            if interfaceID.isEmpty || interfaceName == interfaceID {
                if let data = ptr.pointee.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    totalUpload += Int64(networkData.ifi_obytes)
                    totalDownload += Int64(networkData.ifi_ibytes)
                }
            }
        }
        
        freeifaddrs(interfaceAddresses)
        return (totalUpload, totalDownload)
    }
    
    func calculateBandwidth() -> Bandwidth {
        let current = readInterfaceBandwidth()
        
        var bandwidth = Bandwidth()
        
        if previousBandwidth.upload != 0 {
            bandwidth.upload = current.upload - previousBandwidth.upload
        }
        if previousBandwidth.download != 0 {
            bandwidth.download = current.download - previousBandwidth.download
        }
        
        bandwidth.upload = max(bandwidth.upload, 0)
        bandwidth.download = max(bandwidth.download, 0)
        
        totalBandwidth.upload += bandwidth.upload
        totalBandwidth.download += bandwidth.download
        
        previousBandwidth.upload = current.upload
        previousBandwidth.download = current.download
        
        return bandwidth
    }
    
    func getTotalBandwidth() -> Bandwidth {
        return totalBandwidth
    }
    
    func resetTotalBandwidth() {
        totalBandwidth = Bandwidth()
    }
    
    func getInterfaceDetails() -> NetworkInterface? {
        guard !interfaceID.isEmpty else { return nil }
        
        for interface in SCNetworkInterfaceCopyAll() as NSArray {
            if let bsdName = SCNetworkInterfaceGetBSDName(interface as! SCNetworkInterface),
               bsdName as String == interfaceID,
               let type = SCNetworkInterfaceGetInterfaceType(interface as! SCNetworkInterface),
               let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface as! SCNetworkInterface),
               let address = SCNetworkInterfaceGetHardwareAddressString(interface as! SCNetworkInterface) {
                
                var netInterface = NetworkInterface()
                netInterface.displayName = displayName as String
                netInterface.bsdName = bsdName as String
                netInterface.address = address as String
                
                switch type {
                case kSCNetworkInterfaceTypeEthernet:
                    break
                case kSCNetworkInterfaceTypeIEEE80211, kSCNetworkInterfaceTypeWWAN:
                    break
                case kSCNetworkInterfaceTypeBluetooth:
                    break
                default:
                    break
                }
                
                return netInterface
            }
        }
        
        return nil
    }
    
    func getLocalIPAddress() -> (ipv4: String?, ipv6: String?) {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        var ipv4: String?
        var ipv6: String?
        
        guard getifaddrs(&interfaceAddresses) == 0 else {
            return (nil, nil)
        }
        
        var ptr = interfaceAddresses
        while ptr != nil {
            let addr = ptr!.pointee
            
            if String(cString: addr.ifa_name) == interfaceID {
                var address = addr.ifa_addr.pointee
                
                guard address.sa_family == UInt8(AF_INET) || address.sa_family == UInt8(AF_INET6) else {
                    ptr = addr.ifa_next
                    continue
                }
                
                var ip = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(&address, socklen_t(address.sa_len), &ip, socklen_t(ip.count), nil, socklen_t(0), NI_NUMERICHOST)
                
                let ipStr = String(cString: ip)
                if address.sa_family == UInt8(AF_INET) && !ipStr.isEmpty {
                    ipv4 = ipStr
                } else if address.sa_family == UInt8(AF_INET6) && !ipStr.isEmpty {
                    ipv6 = ipStr
                }
            }
            
            ptr = addr.ifa_next
        }
        
        freeifaddrs(interfaceAddresses)
        return (ipv4, ipv6)
    }
    
    func getWiFiDetails() -> WiFiDetails {
        var details = WiFiDetails()
        
        if let interface = CWWiFiClient.shared().interface(withName: interfaceID) {
            if let ssid = interface.ssid() {
                details.ssid = ssid
            }
            if let bssid = interface.bssid() {
                details.bssid = bssid
            }
            if let countryCode = interface.countryCode() {
                details.countryCode = countryCode
            }
            
            details.rssi = interface.rssiValue()
            details.noise = interface.noiseMeasurement()
            details.standard = interface.activePHYMode().modeDescription
            
            if let channel = interface.wlanChannel() {
                details.channel = "\(channel.channelNumber) (\(channel.channelBand.bandDescription))"
            }
        }
        
        return details
    }
    
    func isInterfaceUp() -> Bool {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return false }
        defer { freeifaddrs(addrs) }
        
        var ptr = first
        while true {
            let name = String(cString: ptr.pointee.ifa_name)
            if name == interfaceID {
                return (ptr.pointee.ifa_flags & UInt32(IFF_UP)) != 0
            }
            if let next = ptr.pointee.ifa_next {
                ptr = next
            } else {
                break
            }
        }
        return false
    }
}

class ProcessNetworkReader {
    private var previousProcesses: [NetworkProcess] = []
    private var numberOfProcesses: Int = 8
    
    func setNumberOfProcesses(_ count: Int) {
        numberOfProcesses = count
    }
    
    func readProcesses() -> [NetworkProcess] {
        if numberOfProcesses == 0 {
            return []
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = ["-P", "-L", "1", "-n", "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch"]
        task.environment = [
            "NSUnbufferedIO": "YES",
            "LC_ALL": "en_US.UTF-8"
        ]
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        defer {
            inputPipe.fileHandleForWriting.closeFile()
            outputPipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
        }
        
        task.standardInput = inputPipe
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
        } catch {
            return []
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8), !output.isEmpty else {
            return []
        }
        
        var currentList: [NetworkProcess] = []
        var firstLine = false
        
        output.enumerateLines { (line, _) in
            if !firstLine {
                firstLine = true
                return
            }
            
            let parsedLine = line.split(separator: ",")
            guard parsedLine.count >= 3 else { return }
            
            var process = NetworkProcess()
            process.time = Date()
            
            let nameArray = parsedLine[0].split(separator: ".")
            if let pid = nameArray.last {
                process.pid = Int(pid) ?? 0
            }
            
            if let app = NSRunningApplication(processIdentifier: pid_t(process.pid)) {
                process.name = app.localizedName ?? nameArray.dropLast().joined(separator: ".")
            } else {
                process.name = nameArray.dropLast().joined(separator: ".")
            }
            
            if process.name.isEmpty {
                process.name = "\(process.pid)"
            }
            
            if let download = Int(parsedLine[1]) {
                process.download = download
            }
            if let upload = Int(parsedLine[2]) {
                process.upload = upload
            }
            
            currentList.append(process)
        }
        
        var processes: [NetworkProcess] = []
        
        if previousProcesses.isEmpty {
            previousProcesses = currentList
            processes = currentList
        } else {
            for pp in previousProcesses {
                if let i = currentList.firstIndex(where: { $0.pid == pp.pid }) {
                    let p = currentList[i]
                    
                    var download = p.download - pp.download
                    var upload = p.upload - pp.upload
                    let time = download == 0 && upload == 0 ? pp.time : Date()
                    currentList[i].time = time
                    
                    if download < 0 { download = 0 }
                    if upload < 0 { upload = 0 }
                    
                    processes.append(NetworkProcess(pid: p.pid, name: p.name, time: time, download: download, upload: upload))
                }
            }
            previousProcesses = currentList
        }
        
        processes.sort { (p1, p2) -> Bool in
            let firstMax = max(p1.download, p1.upload)
            let secondMax = max(p2.download, p2.upload)
            let firstMin = min(p1.download, p1.upload)
            let secondMin = min(p2.download, p2.upload)
            
            if firstMax == secondMax && firstMin == secondMin {
                return p1.time < p2.time
            } else if firstMax == secondMax && firstMin != secondMin {
                return firstMin < secondMin
            }
            return firstMax < secondMax
        }
        
        return Array(processes.suffix(numberOfProcesses).reversed())
    }
}
