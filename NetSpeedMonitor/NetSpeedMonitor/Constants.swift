import Cocoa

struct Constants {
    static let contentWidth: CGFloat = 300
    static let contentHeight: CGFloat = 530
    static let cornerRadius: CGFloat = 18
    
    struct Colors {
        static let downloadGreen = NSColor(red: 0.2, green: 0.85, blue: 0.45, alpha: 1.0)
        static let uploadOrange = NSColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1.0)
    }
    
    struct SystemProcesses {
        static let all = [
            "launchd", "kernel", "syslogd", "configd", "airportd",
            "symptomsd", "mDNSResponder", "wifip2pd", "wifianalyticsd", "rapportd",
            "sharingd", "identityservice", "ControlCenter", "replicatord", "usbmuxd",
            "apsd", "helpd", "trustd", "Stats", "wifivelocityd", "netbiosd"
        ]
    }
    
    struct HelperPatterns {
        static let all = [
            " CN Helper (Renderer)", " CN Helper (GPU)", " CN Helper",
            " Helper (Renderer)", " Helper (GPU)", " Helper",
            " Hel", " He",
            ".helper", "-helper", "_helper"
        ]
    }
}

struct AppMapping {
    let keywords: [String]
    let normalizedName: String
    let displayName: String
    let bundleIdentifier: String?
    
    static let all: [AppMapping] = [
        AppMapping(keywords: ["douyin", "抖音"], normalizedName: "Douyin", displayName: "抖音", bundleIdentifier: "com.bytedance.douyin.desktop"),
        AppMapping(keywords: ["tiktok"], normalizedName: "TikTok", displayName: "TikTok", bundleIdentifier: "com.zhiliaoapp.musically"),
        AppMapping(keywords: ["doubao", "豆包"], normalizedName: "Doubao", displayName: "豆包", bundleIdentifier: "com.larus.nova"),
        AppMapping(keywords: ["trae"], normalizedName: "Trae", displayName: "Trae", bundleIdentifier: "com.trae.app"),
        AppMapping(keywords: ["weixin", "微信", "wechat", "WeChat"], normalizedName: "WeChat", displayName: "微信", bundleIdentifier: "com.tencent.xinWeChat"),
        AppMapping(keywords: ["企业微信", "WeCom"], normalizedName: "WeCom", displayName: "企业微信", bundleIdentifier: "com.tencent.WeCom"),
        AppMapping(keywords: ["qq"], normalizedName: "QQ", displayName: "QQ", bundleIdentifier: "com.tencent.qq"),
        AppMapping(keywords: ["chrome", "谷歌浏览器"], normalizedName: "Chrome", displayName: "Chrome", bundleIdentifier: "com.google.Chrome"),
        AppMapping(keywords: ["safari"], normalizedName: "Safari", displayName: "Safari", bundleIdentifier: "com.apple.Safari"),
        AppMapping(keywords: ["firefox", "火狐"], normalizedName: "Firefox", displayName: "Firefox", bundleIdentifier: "org.mozilla.firefox"),
        AppMapping(keywords: ["finder", "访达"], normalizedName: "Finder", displayName: "访达", bundleIdentifier: "com.apple.finder"),
        AppMapping(keywords: ["terminal", "终端"], normalizedName: "Terminal", displayName: "终端", bundleIdentifier: "com.apple.Terminal"),
        AppMapping(keywords: ["vscode", "visual studio code"], normalizedName: "VSCode", displayName: "VS Code", bundleIdentifier: "com.microsoft.VSCode"),
        AppMapping(keywords: ["xcode"], normalizedName: "Xcode", displayName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
        AppMapping(keywords: ["music", "音乐"], normalizedName: "Music", displayName: "Music", bundleIdentifier: "com.apple.Music"),
        AppMapping(keywords: ["appstore", "应用商店"], normalizedName: "AppStore", displayName: "App Store", bundleIdentifier: "com.apple.AppStore"),
        AppMapping(keywords: ["wps", "wpsoffice"], normalizedName: "WPS", displayName: "WPS Office", bundleIdentifier: "com.kingsoft.wpsoffice.mac"),
        AppMapping(keywords: ["node"], normalizedName: "Node", displayName: "Node.js", bundleIdentifier: nil),
        AppMapping(keywords: ["discord"], normalizedName: "Discord", displayName: "Discord", bundleIdentifier: "com.hnc.Discord"),
        AppMapping(keywords: ["slack"], normalizedName: "Slack", displayName: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"),
        AppMapping(keywords: ["spotify"], normalizedName: "Spotify", displayName: "Spotify", bundleIdentifier: "com.spotify.client"),
        AppMapping(keywords: ["notion"], normalizedName: "Notion", displayName: "Notion", bundleIdentifier: "notion.id"),
        AppMapping(keywords: ["electron"], normalizedName: "Electron", displayName: "Electron", bundleIdentifier: nil)
    ]
    
    static func find(for name: String) -> AppMapping? {
        let nameLower = name.lowercased()
        return all.first { mapping in
            mapping.keywords.contains { nameLower.contains($0.lowercased()) }
        }
    }
}
