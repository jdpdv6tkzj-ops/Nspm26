import Cocoa

struct AppTrafficInfo {
    let name: String
    let speed: Double
    let totalBytes: UInt64
    let icon: NSImage?
    let pid: Int32?
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var timer: Timer?
    var hiddenWindow: NSWindow?
    var panelWindow: NSPanel?
    var glassView: SpeedDisplayView?
    var scrollView: NSScrollView?
    var savedScrollPosition: CGFloat = 0
    
    var uploadSpeed: Double = 0.0
    var downloadSpeed: Double = 0.0
    
    var lastAppBytes: [String: UInt64] = [:]
    var lastProcessBytes: [String: UInt64] = [:]
    var lastAppUpdateTime: Date?
    var currentApps: [AppTrafficInfo] = []
    var topTrafficApps: [AppTrafficInfo] = []
    var appTotalBytes: [String: UInt64] = [:]
    var appIcons: NSCache<NSString, NSImage> = NSCache()
    let dataLock = NSLock()
    
    var showUpload: Bool = false
    var showDownload: Bool = true
    
    let networkReader = NetworkReader()
    let processReader = ProcessNetworkReader()
    var reachability: Reachability?
    
    var isNetworkConnected: Bool = true
    
    var settingsPath: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".netspeed_settings.json")
    }
    
    var trafficDataPath: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".netspeed_traffic.json")
    }
    
    var plistPath: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/com.netspeed.app.plist")
    }
    
    override init() {
        super.init()
        appIcons.countLimit = 50
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("网速监控运行中")
        NSApp.setActivationPolicy(.accessory)
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        
        createHiddenWindow()
        loadSettings()
        loadTrafficData()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.title = "Nspm26"
        
        createMenu()
        
        setupReachability()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateAllData()
        }
        
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    func setupReachability() {
        reachability = Reachability(start: true)
        reachability?.reachable = { [weak self] in
            self?.isNetworkConnected = true
        }
        reachability?.unreachable = { [weak self] in
            self?.isNetworkConnected = false
        }
    }
    
    func createHiddenWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        window.orderOut(nil)
        hiddenWindow = window
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        reachability?.stop()
        hiddenWindow?.close()
        saveTrafficData()
        ProcessInfo.processInfo.enableAutomaticTermination("网速监控已停止")
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func createMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        
        appMenu.addItem(NSMenuItem(title: "关于 Nspm26", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "关闭窗口", action: #selector(closePanel), keyEquivalent: "w"))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "退出 Nspm26", action: #selector(quitApp), keyEquivalent: "q"))
        
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
        
        let statusButton = statusItem.button
        statusButton?.action = #selector(statusBarButtonClicked(_:))
        statusButton?.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }
    
    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc func closePanel() {
        if let scrollView = scrollView {
            savedScrollPosition = scrollView.contentView.bounds.origin.y
        }
        panelWindow?.close()
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        if let panel = panelWindow, panel.isVisible {
            if let scrollView = scrollView {
                savedScrollPosition = scrollView.contentView.bounds.origin.y
            }
            panel.close()
            return
        }
        showGlassPanel()
    }
    
    func showGlassPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Constants.contentWidth, height: Constants.contentHeight),
            styleMask: [.nonactivatingPanel, .borderless, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isMovable = false
        
        let visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: Constants.contentWidth, height: Constants.contentHeight))
        visualEffectView.wantsLayer = true
        visualEffectView.blendingMode = .behindWindow
        if #available(macOS 10.14, *) {
            visualEffectView.material = .hudWindow
        } else {
            visualEffectView.material = .light
        }
        visualEffectView.state = .active
        visualEffectView.layer?.cornerRadius = Constants.cornerRadius
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.25).cgColor
        visualEffectView.layer?.shadowOffset = NSSize(width: 0, height: -5)
        visualEffectView.layer?.shadowRadius = 15
        visualEffectView.layer?.shadowOpacity = 1.0
        visualEffectView.layer?.shadowPath = CGPath(roundedRect: NSRect(x: 0, y: 0, width: Constants.contentWidth, height: Constants.contentHeight), cornerWidth: Constants.cornerRadius, cornerHeight: Constants.cornerRadius, transform: nil)
        
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: Constants.contentWidth, height: Constants.contentHeight))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .allowed
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        
        let clipView = scrollView.contentView
        clipView.drawsBackground = false
        
        let glassView = SpeedDisplayView(frame: NSRect(x: 0, y: 0, width: Constants.contentWidth, height: Constants.contentHeight))
        glassView.autoresizingMask = [.width]
        glassView.showUpload = showUpload
        glassView.showDownload = showDownload
        glassView.isStartupEnabled = isStartupEnabled()
        
        glassView.onQuit = { [weak self] in
            self?.panelWindow?.close()
            self?.quitApp()
        }
        
        glassView.onToggleUpload = { [weak self] in
            self?.toggleUpload()
        }
        
        glassView.onToggleDownload = { [weak self] in
            self?.toggleDownload()
        }
        
        glassView.onToggleStartup = { [weak self] in
            self?.toggleStartup()
        }
        
        glassView.onResetTraffic = { [weak self] in
            self?.resetTraffic()
        }
        
        scrollView.documentView = glassView
        self.scrollView = scrollView
        
        if savedScrollPosition > 0 {
            DispatchQueue.main.async {
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: self.savedScrollPosition))
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
        
        visualEffectView.addSubview(scrollView)
        panel.contentView = visualEffectView
        
        self.glassView = glassView
        
        if let button = statusItem.button {
            let buttonFrame = button.window?.frame ?? NSRect(x: 0, y: 0, width: 100, height: 25)
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            
            var panelX = buttonFrame.origin.x + buttonFrame.width / 2 - Constants.contentWidth / 2
            var panelY = buttonFrame.origin.y - Constants.contentHeight - 8
            
            if panelX < 10 { panelX = 10 }
            if panelX + Constants.contentWidth > screenFrame.width - 10 {
                panelX = screenFrame.width - Constants.contentWidth - 10
            }
            if panelY < 10 { panelY = 10 }
            
            panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        }
        
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panelWindow = panel
        
        updateGlassView()
    }
    
    func updateGlassView() {
        guard let glassView = glassView else { return }
        
        dataLock.lock()
        let apps = currentApps
        let topApps = topTrafficApps
        dataLock.unlock()
        
        glassView.showUpload = showUpload
        glassView.showDownload = showDownload
        glassView.isStartupEnabled = isStartupEnabled()
        glassView.updateSpeed(download: downloadSpeed, upload: uploadSpeed, apps: apps, topTrafficApps: topApps)
    }
    
    func resetTraffic() {
        networkReader.resetTotalBandwidth()
        
        dataLock.lock()
        appTotalBytes.removeAll()
        dataLock.unlock()
        
        saveTrafficData()
        updateGlassView()
    }
    
    func updateAllData() {
        let bandwidth = networkReader.calculateBandwidth()
        
        downloadSpeed = Double(bandwidth.download)
        uploadSpeed = Double(bandwidth.upload)
        
        updateAppTrafficSync()
        updateUI()
    }
    
    func updateAppTrafficSync() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = ["-P", "-n", "-l", "1", "-x"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if let output = String(data: data, encoding: .utf8) {
                calculateAppSpeeds(output)
            }
        } catch { }
    }
    
    func calculateAppSpeeds(_ output: String) {
        var currentProcessBytes: [String: (bytes: UInt64, appName: String, pid: Int32?)] = [:]
        let now = Date()
        
        var electronProcesses: [(pid: Int32, bytesIn: UInt64, bytesOut: UInt64)] = []
        var helperProcesses: [String: [(bytes: UInt64, pid: Int32)]] = [:]
        
        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("time") || line.isEmpty { continue }
            
            if let processInfo = parseNettopLine(line) {
                let (processName, pid, bytesIn, bytesOut) = processInfo
                
                if ProcessNameHelper.isSystemProcess(processName) { continue }
                
                if processName.lowercased() == "electron" {
                    electronProcesses.append((pid, bytesIn, bytesOut))
                    continue
                }
                
                if processName.contains("Helper") || processName.contains("Hel") {
                    let helperName = processName.replacingOccurrences(of: " Helper", with: "")
                        .replacingOccurrences(of: " Hel", with: "")
                        .replacingOccurrences(of: " CN", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    let appName = ProcessNameHelper.normalizeAppName(helperName)
                    if helperProcesses[appName] == nil {
                        helperProcesses[appName] = []
                    }
                    helperProcesses[appName]?.append((bytesIn + bytesOut, pid))
                    continue
                }
                
                let appName = ProcessNameHelper.normalizeAppName(processName)
                let totalBytes = bytesIn + bytesOut
                let key = "\(processName).\(pid)"
                currentProcessBytes[key] = (bytes: totalBytes, appName: appName, pid: pid)
            }
        }
        
        for electron in electronProcesses {
            var matchedApp: String? = nil
            var minPidDiff = Int32.max
            
            for (appName, helpers) in helperProcesses {
                for helper in helpers {
                    let pidDiff = abs(electron.pid - helper.pid)
                    if pidDiff < minPidDiff && pidDiff < 1000 {
                        minPidDiff = pidDiff
                        matchedApp = appName
                    }
                }
            }
            
            if let app = matchedApp {
                let appName = ProcessNameHelper.normalizeAppName(app)
                let totalBytes = electron.bytesIn + electron.bytesOut
                let key = "Electron.\(electron.pid)"
                currentProcessBytes[key] = (bytes: totalBytes, appName: appName, pid: electron.pid)
            } else {
                let key = "Electron.\(electron.pid)"
                currentProcessBytes[key] = (bytes: electron.bytesIn + electron.bytesOut, appName: "Electron", pid: electron.pid)
            }
        }
        
        for (appName, helpers) in helperProcesses {
            var totalBytes: UInt64 = 0
            var firstPid: Int32? = nil
            for (index, helper) in helpers.enumerated() {
                totalBytes += helper.bytes
                if index == 0 {
                    firstPid = helper.pid
                }
                let key = "Helper.\(helper.pid)"
                currentProcessBytes[key] = (bytes: helper.bytes, appName: appName, pid: helper.pid)
            }
        }
        
        dataLock.lock()
        
        let timeDiff: Double
        if let lastTime = lastAppUpdateTime {
            timeDiff = now.timeIntervalSince(lastTime)
        } else {
            timeDiff = 0
        }
        
        var appSpeeds: [String: (speed: Double, pid: Int32?)] = [:]
        
        if timeDiff > 0 {
            for (processInfo, info) in currentProcessBytes {
                if let prevBytes = lastProcessBytes[processInfo] {
                    if info.bytes > prevBytes {
                        let bytesDiff = info.bytes - prevBytes
                        let speed = Double(bytesDiff) / timeDiff
                        
                        if var existing = appSpeeds[info.appName] {
                            existing.speed += speed
                            appSpeeds[info.appName] = existing
                        } else {
                            appSpeeds[info.appName] = (speed: speed, pid: info.pid)
                        }
                        
                        appTotalBytes[info.appName, default: 0] += bytesDiff
                    }
                }
            }
        }
        
        lastProcessBytes = currentProcessBytes.mapValues { $0.bytes }
        lastAppUpdateTime = now
        
        var keysToRemove: [String] = []
        for key in lastProcessBytes.keys {
            if currentProcessBytes[key] == nil {
                keysToRemove.append(key)
            }
        }
        for key in keysToRemove {
            lastProcessBytes.removeValue(forKey: key)
        }
        
        let totalBytesCopy = appTotalBytes
        dataLock.unlock()
        
        var apps: [AppTrafficInfo] = []
        for (name, info) in appSpeeds {
            let icon = getAppIcon(forPid: info.pid, name: name)
            let totalBytes = totalBytesCopy[name] ?? 0
            let displayName = getLocalizedAppName(forPid: info.pid, processName: name)
            
            apps.append(AppTrafficInfo(
                name: displayName,
                speed: info.speed,
                totalBytes: totalBytes,
                icon: icon,
                pid: info.pid
            ))
        }
        
        apps.sort { $0.speed > $1.speed }
        
        var topApps: [AppTrafficInfo] = []
        let sortedByTotal = totalBytesCopy.sorted { $0.value > $1.value }
        
        for (name, totalBytes) in sortedByTotal.prefix(3) {
            let icon = getAppIcon(forPid: nil, name: name)
            let displayName = getLocalizedAppName(forPid: nil, processName: name)
            topApps.append(AppTrafficInfo(
                name: displayName,
                speed: 0,
                totalBytes: totalBytes,
                icon: icon,
                pid: nil
            ))
        }
        
        dataLock.lock()
        self.currentApps = Array(apps.prefix(3))
        self.topTrafficApps = topApps
        dataLock.unlock()
    }
    
    private func parseNettopLine(_ line: String) -> (processName: String, pid: Int32, bytesIn: UInt64, bytesOut: UInt64)? {
        guard !line.isEmpty && !line.hasPrefix("time") else { return nil }
        
        let regex = try? NSRegularExpression(pattern: #"^(\d{2}:\d{2}:\d{2}\.\d+)\s+(.+?)\.(\d+)\s+(\d+)\s+(\d+)"#, options: [])
        let nsRange = NSRange(line.startIndex..., in: line)
        
        guard let match = regex?.firstMatch(in: line, options: [], range: nsRange) else {
            return nil
        }
        
        guard let processNameRange = Range(match.range(at: 2), in: line),
              let pidRange = Range(match.range(at: 3), in: line),
              let bytesInRange = Range(match.range(at: 4), in: line),
              let bytesOutRange = Range(match.range(at: 5), in: line) else {
            return nil
        }
        
        let processName = String(line[processNameRange])
        guard let pid = Int32(String(line[pidRange])),
              let bytesIn = UInt64(String(line[bytesInRange])),
              let bytesOut = UInt64(String(line[bytesOutRange])) else {
            return nil
        }
        
        return (processName, pid, bytesIn, bytesOut)
    }
    
    func getAppIcon(forPid pid: Int32?, name: String) -> NSImage? {
        let cacheKey = "\(name)_\(pid ?? 0)" as NSString
        if let cachedIcon = appIcons.object(forKey: cacheKey) {
            return cachedIcon
        }
        
        var icon: NSImage? = nil
        
        if let pid = pid, pid > 0 {
            if let app = NSRunningApplication(processIdentifier: pid) {
                icon = app.icon
            }
        }
        
        if icon == nil {
            if let mapping = AppMapping.find(for: name), let bundleId = mapping.bundleIdentifier {
                for app in NSWorkspace.shared.runningApplications {
                    if let appBundleId = app.bundleIdentifier,
                       appBundleId.lowercased().contains(bundleId.lowercased()) {
                        icon = app.icon
                        break
                    }
                }
            }
        }
        
        if icon == nil {
            let runningApps = NSWorkspace.shared.runningApplications
            let nameLower = name.lowercased()
            
            for app in runningApps {
                guard !app.isHidden else { continue }
                
                if let localizedName = app.localizedName {
                    let localizedNameLower = localizedName.lowercased()
                    
                    if localizedNameLower == nameLower {
                        icon = app.icon
                        break
                    }
                    
                    if localizedNameLower.contains(nameLower) || nameLower.contains(localizedNameLower) {
                        icon = app.icon
                    }
                }
                
                if icon == nil, let bundleId = app.bundleIdentifier {
                    let bundleIdLower = bundleId.lowercased()
                    
                    if bundleIdLower.contains(nameLower) {
                        icon = app.icon
                    }
                    
                    let bundleName = bundleId.components(separatedBy: ".").last ?? ""
                    if bundleName.lowercased() == nameLower {
                        icon = app.icon
                        break
                    }
                }
                
                if icon != nil { break }
            }
        }
        
        if icon == nil {
            if let mapping = AppMapping.find(for: name) {
                for app in NSWorkspace.shared.runningApplications {
                    if let bundleId = app.bundleIdentifier,
                       bundleId.lowercased().contains(mapping.normalizedName.lowercased()) {
                        icon = app.icon
                        break
                    }
                }
                
                if icon == nil, let bundleId = mapping.bundleIdentifier {
                    let appPaths = [
                        "/Applications/\(mapping.displayName).app",
                        "/Applications/\(mapping.normalizedName).app",
                        NSHomeDirectory() + "/Applications/\(mapping.displayName).app",
                        NSHomeDirectory() + "/Applications/\(mapping.normalizedName).app"
                    ]
                    
                    for appPath in appPaths {
                        if FileManager.default.fileExists(atPath: appPath) {
                            let appIcon = NSWorkspace.shared.icon(forFile: appPath)
                            if appIcon.isValid {
                                icon = appIcon
                                break
                            }
                        }
                    }
                    
                    if icon == nil {
                        let searchPaths = ["/Applications", NSHomeDirectory() + "/Applications"]
                        for searchPath in searchPaths {
                            if let apps = try? FileManager.default.contentsOfDirectory(atPath: searchPath) {
                                for appName in apps where appName.hasSuffix(".app") {
                                    let appPath = searchPath + "/" + appName
                                    if let infoPlist = NSDictionary(contentsOfFile: appPath + "/Contents/Info.plist"),
                                       let appBundleId = infoPlist["CFBundleIdentifier"] as? String,
                                       appBundleId.lowercased().contains(bundleId.lowercased()) {
                                        let foundIcon = NSWorkspace.shared.icon(forFile: appPath)
                                        if foundIcon.isValid {
                                            icon = foundIcon
                                        }
                                        break
                                    }
                                }
                                if icon != nil { break }
                            }
                        }
                    }
                }
            }
        }
        
        if icon == nil {
            if #available(macOS 11.0, *) {
                icon = NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
            } else {
                icon = NSImage(named: NSImage.applicationIconName)
            }
        }
        
        if let icon = icon {
            appIcons.setObject(icon, forKey: cacheKey)
        }
        
        return icon
    }
    
    func getLocalizedAppName(forPid pid: Int32?, processName: String) -> String {
        if let pid = pid, pid > 0 {
            if let app = NSRunningApplication(processIdentifier: pid) {
                if let localizedName = app.localizedName, !localizedName.isEmpty {
                    return localizedName
                }
            }
        }
        
        let runningApps = NSWorkspace.shared.runningApplications
        let processNameLower = processName.lowercased()
        
        for app in runningApps {
            guard !app.isHidden else { continue }
            
            if let localizedName = app.localizedName {
                let localizedNameLower = localizedName.lowercased()
                
                if localizedNameLower == processNameLower {
                    return localizedName
                }
                
                if localizedNameLower.contains(processNameLower) || processNameLower.contains(localizedNameLower) {
                    return localizedName
                }
            }
            
            if let bundleId = app.bundleIdentifier {
                let bundleIdLower = bundleId.lowercased()
                
                if bundleIdLower.contains(processNameLower) {
                    return app.localizedName ?? processName
                }
                
                let bundleName = bundleId.components(separatedBy: ".").last ?? ""
                if bundleName.lowercased() == processNameLower {
                    return app.localizedName ?? processName
                }
            }
        }
        
        if let mapping = AppMapping.find(for: processName) {
            return mapping.displayName
        }
        
        return ProcessNameHelper.cleanProcessName(processName)
    }
    
    func updateUI() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateUI()
            }
            return
        }
        
        var titleParts: [String] = []
        if showDownload {
            titleParts.append("↓\(SpeedFormatter.formatSpeedShort(downloadSpeed))")
        }
        if showUpload {
            titleParts.append("↑\(SpeedFormatter.formatSpeedShort(uploadSpeed))")
        }
        statusItem.title = titleParts.isEmpty ? "Nspm26" : titleParts.joined(separator: " ")
        
        if panelWindow?.isVisible == true {
            updateGlassView()
        }
    }
    
    @objc func toggleUpload() {
        showUpload.toggle()
        saveSettings()
        updateUI()
    }
    
    @objc func toggleDownload() {
        showDownload.toggle()
        saveSettings()
        updateUI()
    }
    
    @objc func toggleStartup() {
        if isStartupEnabled() {
            disableStartup()
        } else {
            enableStartup()
        }
        updateUI()
    }
    
    @objc func quitApp() {
        timer?.invalidate()
        NSApp.terminate(nil)
    }
    
    func isStartupEnabled() -> Bool {
        return FileManager.default.fileExists(atPath: plistPath.path)
    }
    
    func enableStartup() {
        let appPath = Bundle.main.bundlePath
        let plistContent = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.netspeed.app</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>\(appPath)</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
"""
        
        do {
            try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create startup plist: \(error)")
        }
    }
    
    func disableStartup() {
        do {
            try FileManager.default.removeItem(at: plistPath)
        } catch {
            print("Failed to remove startup plist: \(error)")
        }
    }
    
    func saveSettings() {
        let settings: [String: Any] = [
            "showUpload": showUpload,
            "showDownload": showDownload
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            try data.write(to: settingsPath)
        } catch {
            print("Failed to save settings: \(error)")
        }
        
        saveTrafficData()
    }
    
    func saveTrafficData() {
        dataLock.lock()
        let totalBytes = appTotalBytes
        let networkTotal = networkReader.getTotalBandwidth()
        dataLock.unlock()
        
        let trafficData: [String: Any] = [
            "totalBytes": totalBytes.mapValues { String($0) },
            "networkTotalUpload": String(networkTotal.upload),
            "networkTotalDownload": String(networkTotal.download),
            "lastUpdate": Date().timeIntervalSince1970
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: trafficData, options: .prettyPrinted)
            try data.write(to: trafficDataPath)
        } catch {
            print("Failed to save traffic data: \(error)")
        }
    }
    
    func loadSettings() {
        guard FileManager.default.fileExists(atPath: settingsPath.path) else { return }
        
        do {
            let data = try Data(contentsOf: settingsPath)
            if let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                showUpload = settings["showUpload"] as? Bool ?? false
                showDownload = settings["showDownload"] as? Bool ?? true
            }
        } catch {
            print("Failed to load settings: \(error)")
        }
    }
    
    func loadTrafficData() {
        guard FileManager.default.fileExists(atPath: trafficDataPath.path) else { return }
        
        do {
            let data = try Data(contentsOf: trafficDataPath)
            if let trafficData = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let totalBytes = trafficData["totalBytes"] as? [String: String] {
                    dataLock.lock()
                    appTotalBytes = totalBytes.compactMapValues { UInt64($0) }
                    dataLock.unlock()
                }
            }
        } catch {
            print("Failed to load traffic data: \(error)")
        }
    }
}
