import Cocoa

struct AppDisplayInfo {
    let name: String
    let speed: Double
    let totalBytes: UInt64
    let icon: NSImage?
}

private struct CachedFonts {
    let titleFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    let valueFont = NSFont.systemFont(ofSize: 24, weight: .bold)
    let appFont = NSFont.systemFont(ofSize: 13, weight: .medium)
    let smallFont = NSFont.systemFont(ofSize: 11, weight: .regular)
    let tinyFont = NSFont.systemFont(ofSize: 10, weight: .light)
    let buttonFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    
    static let shared = CachedFonts()
}

private struct CachedAttributes {
    var titleAttrs: [NSAttributedString.Key: Any] = [:]
    var valueAttrs: [NSAttributedString.Key: Any] = [:]
    var appAttrs: [NSAttributedString.Key: Any] = [:]
    var smallAttrs: [NSAttributedString.Key: Any] = [:]
    var tinyAttrs: [NSAttributedString.Key: Any] = [:]
    
    mutating func update(for isDarkMode: Bool) {
        let fonts = CachedFonts.shared
        
        let titleColor: NSColor = isDarkMode ? NSColor.white.withAlphaComponent(0.7) : NSColor.black.withAlphaComponent(0.7)
        let valueColor: NSColor = isDarkMode ? NSColor.white.withAlphaComponent(0.95) : NSColor.black.withAlphaComponent(0.85)
        let speedColor: NSColor = isDarkMode ? NSColor.white.withAlphaComponent(0.9) : NSColor.black.withAlphaComponent(0.8)
        let tinyColor: NSColor = isDarkMode ? NSColor.white.withAlphaComponent(0.6) : NSColor.black.withAlphaComponent(0.5)
        let shadowColor: NSColor = isDarkMode ? NSColor.black.withAlphaComponent(0.3) : NSColor.white.withAlphaComponent(0.3)
        
        let shadow = NSShadow()
        shadow.shadowColor = shadowColor
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 2
        
        titleAttrs = [.font: fonts.titleFont, .foregroundColor: titleColor, .shadow: shadow]
        valueAttrs = [.font: fonts.valueFont, .foregroundColor: valueColor, .shadow: shadow]
        appAttrs = [.font: fonts.appFont, .foregroundColor: valueColor, .shadow: shadow]
        smallAttrs = [.font: fonts.smallFont, .foregroundColor: speedColor, .shadow: shadow]
        tinyAttrs = [.font: fonts.tinyFont, .foregroundColor: tinyColor, .shadow: shadow]
    }
    
    static var shared = CachedAttributes()
}

class SpeedDisplayView: NSView {
    private var downloadSpeed: Double = 0
    private var uploadSpeed: Double = 0
    private var apps: [AppDisplayInfo] = []
    private var topTrafficApps: [AppDisplayInfo] = []
    
    var onQuit: (() -> Void)?
    var onToggleUpload: (() -> Void)?
    var onToggleDownload: (() -> Void)?
    var onToggleStartup: (() -> Void)?
    var onResetTraffic: (() -> Void)?
    
    var showUpload: Bool = false
    var showDownload: Bool = true
    var isStartupEnabled: Bool = false
    
    private var toggleButtons: [(rect: NSRect, action: (() -> Void)?)] = []
    private var hoveredButton: Int? = nil
    
    private var cachedIsDarkMode: Bool = false
    private var lastDarkModeCheck: Date?
    private let darkModeCacheInterval: TimeInterval = 0.5
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = Constants.cornerRadius
        layer?.masksToBounds = true
        
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    
    func updateSpeed(download: Double, upload: Double, apps: [AppTrafficInfo], topTrafficApps: [AppTrafficInfo]) {
        self.downloadSpeed = download
        self.uploadSpeed = upload
        self.apps = apps.map { AppDisplayInfo(name: $0.name, speed: $0.speed, totalBytes: $0.totalBytes, icon: $0.icon) }
        self.topTrafficApps = topTrafficApps.map { AppDisplayInfo(name: $0.name, speed: $0.speed, totalBytes: $0.totalBytes, icon: $0.icon) }
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let clipPath = NSBezierPath(roundedRect: bounds, xRadius: Constants.cornerRadius, yRadius: Constants.cornerRadius)
        clipPath.addClip()
        
        toggleButtons.removeAll()
        
        let isDarkMode = getCachedIsDarkMode()
        CachedAttributes.shared.update(for: isDarkMode)
        
        drawLiquidGlassBackground(isDarkMode: isDarkMode)
        drawContent(isDarkMode: isDarkMode)
    }
    
    private func getCachedIsDarkMode() -> Bool {
        let now = Date()
        if let lastCheck = lastDarkModeCheck, now.timeIntervalSince(lastCheck) < darkModeCacheInterval {
            return cachedIsDarkMode
        }
        
        cachedIsDarkMode = isDarkBackground()
        lastDarkModeCheck = now
        return cachedIsDarkMode
    }
    
    private func isDarkBackground() -> Bool {
        if let window = window {
            if #available(macOS 10.14, *) {
                let appearance = window.effectiveAppearance
                if appearance.name == .darkAqua { return true }
                if appearance.name == .aqua { return false }
            }
        }
        
        guard let window = window else { return false }
        
        let frame = window.convertToScreen(bounds)
        guard let cgImage = CGWindowListCreateImage(
            frame,
            .optionOnScreenBelowWindow,
            CGWindowID(window.windowNumber),
            [.boundsIgnoreFraming, .bestResolution]
        ) else { return false }
        
        guard let dataProvider = cgImage.dataProvider else { return false }
        let data = dataProvider.data
        guard let bytes = CFDataGetBytePtr(data) else { return false }
        
        let length = CFDataGetLength(data)
        var totalBrightness: CGFloat = 0
        var pixelCount: CGFloat = 0
        let sampleStep = max(1, length / (4 * 1000))
        
        for i in stride(from: 0, to: length - 3, by: sampleStep * 4) {
            let r = CGFloat(bytes[i])
            let g = CGFloat(bytes[i + 1])
            let b = CGFloat(bytes[i + 2])
            let brightness = (r + g + b) / 3.0 / 255.0
            totalBrightness += brightness
            pixelCount += 1
        }
        
        return pixelCount > 0 && (totalBrightness / pixelCount) < 0.3
    }
    
    private func drawLiquidGlassBackground(isDarkMode: Bool) {
        let borderPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: Constants.cornerRadius, yRadius: Constants.cornerRadius)
        borderPath.lineWidth = 1.0
        NSColor.white.withAlphaComponent(0.3).setStroke()
        borderPath.stroke()
        
        let highlightPath = NSBezierPath()
        highlightPath.move(to: NSPoint(x: bounds.minX + Constants.cornerRadius, y: bounds.maxY - 1))
        highlightPath.line(to: NSPoint(x: bounds.maxX - Constants.cornerRadius, y: bounds.maxY - 1))
        highlightPath.lineWidth = 1.5
        NSColor.white.withAlphaComponent(0.4).setStroke()
        highlightPath.stroke()
    }
    
    private func drawContent(isDarkMode: Bool) {
        let padding: CGFloat = 16
        var y = bounds.maxY - padding
        
        let attrs = CachedAttributes.shared
        let fonts = CachedFonts.shared
        
        y -= 4
        let headerText = NSAttributedString(string: "网络速度", attributes: attrs.titleAttrs)
        headerText.draw(at: NSPoint(x: padding, y: y - fonts.titleFont.pointSize))
        y -= 26
        
        if showDownload {
            let downloadAttrs: [NSAttributedString.Key: Any] = [
                .font: fonts.valueFont,
                .foregroundColor: Constants.Colors.downloadGreen
            ]
            let downloadText = NSAttributedString(string: "▼", attributes: downloadAttrs)
            downloadText.draw(at: NSPoint(x: padding, y: y - fonts.valueFont.pointSize))
            
            let speedText = NSAttributedString(string: SpeedFormatter.formatSpeed(downloadSpeed), attributes: attrs.valueAttrs)
            speedText.draw(at: NSPoint(x: padding + 32, y: y - fonts.valueFont.pointSize))
            y -= 36
        }
        
        if showUpload {
            let uploadAttrs: [NSAttributedString.Key: Any] = [
                .font: fonts.valueFont,
                .foregroundColor: Constants.Colors.uploadOrange
            ]
            let uploadText = NSAttributedString(string: "▲", attributes: uploadAttrs)
            uploadText.draw(at: NSPoint(x: padding, y: y - fonts.valueFont.pointSize))
            
            let speedText = NSAttributedString(string: SpeedFormatter.formatSpeed(uploadSpeed), attributes: attrs.valueAttrs)
            speedText.draw(at: NSPoint(x: padding + 32, y: y - fonts.valueFont.pointSize))
            y -= 36
        }
        
        y -= 12
        
        let appTitleText = NSAttributedString(string: "应用下载速度", attributes: attrs.titleAttrs)
        appTitleText.draw(at: NSPoint(x: padding, y: y - fonts.titleFont.pointSize))
        y -= 24
        
        for i in 0..<3 {
            if i < apps.count {
                let app = apps[i]
                drawAppRow(at: &y, padding: padding, app: app, index: i, isDarkMode: isDarkMode, showSpeed: true)
            } else {
                y -= 34
            }
        }
        
        y -= 12
        
        let topTrafficTitle = NSAttributedString(string: "流量使用排行", attributes: attrs.titleAttrs)
        topTrafficTitle.draw(at: NSPoint(x: padding, y: y - fonts.titleFont.pointSize))
        y -= 24
        
        for i in 0..<3 {
            if i < topTrafficApps.count {
                let app = topTrafficApps[i]
                drawAppRow(at: &y, padding: padding, app: app, index: i, isDarkMode: isDarkMode, showSpeed: false)
            } else {
                y -= 34
            }
        }
        
        y -= 12
        
        let optionsTitle = NSAttributedString(string: "选项", attributes: attrs.titleAttrs)
        optionsTitle.draw(at: NSPoint(x: padding, y: y - fonts.titleFont.pointSize))
        y -= 24
        
        let toggleItems: [(String, Bool, (() -> Void)?)] = [
            ("显示上传速度", showUpload, onToggleUpload),
            ("显示下载速度", showDownload, onToggleDownload),
            ("开机自动启动", isStartupEnabled, onToggleStartup)
        ]
        
        for (index, (title, isEnabled, action)) in toggleItems.enumerated() {
            let pillHeight: CGFloat = 22
            let pillRect = NSRect(x: padding, y: y - pillHeight, width: bounds.width - padding * 2, height: pillHeight)
            let isHovered = hoveredButton == index
            drawPillBackground(in: pillRect, isDark: isDarkMode, isHovered: isHovered)
            
            let buttonRect = NSRect(x: padding - 4, y: y - 18, width: bounds.width - padding * 2 + 8, height: 24)
            toggleButtons.append((rect: buttonRect, action: action))
            
            let centerY = y - pillHeight / 2
            let switchRect = NSRect(x: bounds.width - padding - 44, y: centerY - 9, width: 36, height: 18)
            drawGlassSwitch(in: switchRect, isOn: isEnabled, isHovered: isHovered, isDark: isDarkMode)
            
            let itemText = NSAttributedString(string: title, attributes: attrs.smallAttrs)
            let textSize = itemText.size()
            itemText.draw(at: NSPoint(x: padding + 8, y: centerY - textSize.height / 2))
            y -= pillHeight + 6
        }
        
        y -= 12
        
        let resetButtonRect = NSRect(x: padding, y: y - 20, width: 80, height: 24)
        let isResetHovered = hoveredButton == 100
        drawGlassButton(in: resetButtonRect, title: "重置流量", isHovered: isResetHovered, color: .systemBlue, isDark: isDarkMode)
        toggleButtons.append((rect: resetButtonRect, action: onResetTraffic))
        
        let quitButtonRect = NSRect(x: bounds.width - padding - 60, y: y - 20, width: 60, height: 24)
        let isQuitHovered = hoveredButton == 101
        drawGlassButton(in: quitButtonRect, title: "退出", isHovered: isQuitHovered, color: .systemRed, isDark: isDarkMode)
        toggleButtons.append((rect: quitButtonRect, action: onQuit))
    }
    
    private func drawAppRow(at y: inout CGFloat, padding: CGFloat, app: AppDisplayInfo, index: Int, isDarkMode: Bool, showSpeed: Bool) {
        let attrs = CachedAttributes.shared
        let fonts = CachedFonts.shared
        
        let pillHeight: CGFloat = 28
        let pillRect = NSRect(x: padding, y: y - pillHeight, width: bounds.width - padding * 2, height: pillHeight)
        drawPillBackground(in: pillRect, isDark: isDarkMode)
        
        let centerY = y - pillHeight / 2
        
        if let icon = app.icon {
            let iconSize: CGFloat = 20
            let iconRect = NSRect(x: padding + 6, y: centerY - iconSize / 2, width: iconSize, height: iconSize)
            let roundedImage = roundCorners(image: icon, radius: 4)
            roundedImage.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            let dotSize: CGFloat = 8
            let dotRect = NSRect(x: padding + 12, y: centerY - dotSize / 2, width: dotSize, height: dotSize)
            let dotPath = NSBezierPath(ovalIn: dotRect)
            let colors: [NSColor] = [.systemBlue, .systemPurple, .systemTeal]
            colors[index].setFill()
            dotPath.fill()
        }
        
        let appNameText = NSAttributedString(string: app.name, attributes: attrs.appAttrs)
        let nameSize = appNameText.size()
        appNameText.draw(at: NSPoint(x: padding + 32, y: centerY - nameSize.height / 2))
        
        if showSpeed {
            let speedText = NSAttributedString(string: SpeedFormatter.formatSpeed(app.speed), attributes: attrs.smallAttrs)
            let speedWidth = speedText.size().width
            speedText.draw(at: NSPoint(x: bounds.width - padding - speedWidth - 8, y: centerY - fonts.smallFont.pointSize / 2))
        } else {
            let totalText = NSAttributedString(string: SpeedFormatter.formatTotalBytes(app.totalBytes), attributes: attrs.smallAttrs)
            let totalWidth = totalText.size().width
            totalText.draw(at: NSPoint(x: bounds.width - padding - totalWidth - 8, y: centerY - fonts.smallFont.pointSize / 2))
        }
        
        y -= pillHeight + 6
    }
    
    private func drawGlassSeparator(at y: CGFloat, padding: CGFloat, isDark: Bool) {
        let color: NSColor = isDark ? NSColor.white.withAlphaComponent(0.15) : NSColor.black.withAlphaComponent(0.1)
        let gradient = NSGradient(colors: [NSColor.clear, color, NSColor.clear])
        gradient?.draw(in: NSRect(x: padding, y: y - 0.5, width: bounds.width - padding * 2, height: 1), angle: 0)
    }
    
    private func drawPillBackground(in rect: NSRect, isDark: Bool, isHovered: Bool = false) {
        let cornerRadius = rect.height / 2
        let pillPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        if isDark {
            NSColor.white.withAlphaComponent(isHovered ? 0.12 : 0.08).setFill()
            pillPath.fill()
            pillPath.lineWidth = 0.5
            NSColor.white.withAlphaComponent(0.15).setStroke()
            pillPath.stroke()
        } else {
            NSColor.black.withAlphaComponent(isHovered ? 0.08 : 0.04).setFill()
            pillPath.fill()
            pillPath.lineWidth = 0.5
            NSColor.black.withAlphaComponent(0.1).setStroke()
            pillPath.stroke()
        }
    }
    
    private func drawGlassSwitch(in rect: NSRect, isOn: Bool, isHovered: Bool, isDark: Bool) {
        let cornerRadius = rect.height / 2
        let capsulePath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        if isDark {
            NSColor.white.withAlphaComponent(isOn ? 0.3 : 0.15).setFill()
            capsulePath.fill()
            capsulePath.lineWidth = 0.5
            NSColor.white.withAlphaComponent(0.2).setStroke()
            capsulePath.stroke()
            
            let thumbSize = rect.height - 6
            let thumbX = isOn ? rect.maxX - thumbSize - 3 : rect.minX + 3
            let thumbRect = NSRect(x: thumbX, y: rect.minY + 3, width: thumbSize, height: thumbSize)
            
            let thumbPath = NSBezierPath(ovalIn: thumbRect)
            NSColor.white.withAlphaComponent(0.9).setFill()
            thumbPath.fill()
            
            let thumbBorderPath = NSBezierPath(ovalIn: thumbRect.insetBy(dx: 0.5, dy: 0.5))
            thumbBorderPath.lineWidth = 0.5
            NSColor.white.withAlphaComponent(0.3).setStroke()
            thumbBorderPath.stroke()
        } else {
            NSColor.black.withAlphaComponent(isOn ? 0.25 : 0.1).setFill()
            capsulePath.fill()
            capsulePath.lineWidth = 0.5
            NSColor.black.withAlphaComponent(0.15).setStroke()
            capsulePath.stroke()
            
            let thumbSize = rect.height - 6
            let thumbX = isOn ? rect.maxX - thumbSize - 3 : rect.minX + 3
            let thumbRect = NSRect(x: thumbX, y: rect.minY + 3, width: thumbSize, height: thumbSize)
            
            let thumbPath = NSBezierPath(ovalIn: thumbRect)
            NSColor.black.withAlphaComponent(0.8).setFill()
            thumbPath.fill()
            
            let thumbBorderPath = NSBezierPath(ovalIn: thumbRect.insetBy(dx: 0.5, dy: 0.5))
            thumbBorderPath.lineWidth = 0.5
            NSColor.black.withAlphaComponent(0.2).setStroke()
            thumbBorderPath.stroke()
        }
    }
    
    private func drawGlassButton(in rect: NSRect, title: String, isHovered: Bool, color: NSColor, isDark: Bool) {
        let cornerRadius: CGFloat = 12
        let buttonPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        let fonts = CachedFonts.shared
        
        if isDark {
            NSColor.white.withAlphaComponent(isHovered ? 0.2 : 0.1).setFill()
            buttonPath.fill()
            
            let borderPath = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
            borderPath.lineWidth = 0.5
            NSColor.white.withAlphaComponent(isHovered ? 0.3 : 0.2).setStroke()
            borderPath.stroke()
            
            let attrs: [NSAttributedString.Key: Any] = [.font: fonts.buttonFont, .foregroundColor: NSColor.white.withAlphaComponent(0.85)]
            let text = NSAttributedString(string: title, attributes: attrs)
            let textSize = text.size()
            text.draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2))
        } else {
            NSColor.black.withAlphaComponent(isHovered ? 0.15 : 0.08).setFill()
            buttonPath.fill()
            
            let borderPath = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
            borderPath.lineWidth = 0.5
            NSColor.black.withAlphaComponent(isHovered ? 0.2 : 0.15).setStroke()
            borderPath.stroke()
            
            let attrs: [NSAttributedString.Key: Any] = [.font: fonts.buttonFont, .foregroundColor: NSColor.black.withAlphaComponent(0.7)]
            let text = NSAttributedString(string: title, attributes: attrs)
            let textSize = text.size()
            text.draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2))
        }
    }
    
    private func roundCorners(image: NSImage, radius: CGFloat) -> NSImage {
        let size = image.size
        let roundedImage = NSImage(size: size)
        
        roundedImage.lockFocus()
        let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: radius, yRadius: radius)
        path.addClip()
        image.draw(in: NSRect(origin: .zero, size: size))
        roundedImage.unlockFocus()
        
        return roundedImage
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        for button in toggleButtons {
            if button.rect.contains(location) {
                button.action?()
                return
            }
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        var newHoveredButton: Int? = nil
        
        for (index, button) in toggleButtons.enumerated() {
            if button.rect.contains(location) {
                newHoveredButton = index
                break
            }
        }
        
        if newHoveredButton != hoveredButton {
            hoveredButton = newHoveredButton
            needsDisplay = true
        }
        
        if hoveredButton != nil {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if hoveredButton != nil {
            hoveredButton = nil
            needsDisplay = true
        }
        NSCursor.arrow.set()
    }
}
