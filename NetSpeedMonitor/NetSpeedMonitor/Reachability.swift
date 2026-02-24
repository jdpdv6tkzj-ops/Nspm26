import Cocoa
import SystemConfiguration

class Reachability {
    private var reachabilityRef: SCNetworkReachability?
    private var isRunning: Bool = false
    
    var reachable: (() -> Void)?
    var unreachable: (() -> Void)?
    
    var isReachable: Bool {
        guard let ref = reachabilityRef else { return false }
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(ref, &flags)
        return isReachableWithFlags(flags)
    }
    
    init(start: Bool = false) {
        reachabilityRef = SCNetworkReachabilityCreateWithName(nil, "1.1.1.1")
        if start {
            self.start()
        }
    }
    
    deinit {
        stop()
    }
    
    func start() {
        guard let ref = reachabilityRef, !isRunning else { return }
        
        var context = SCNetworkReachabilityContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        SCNetworkReachabilitySetCallback(ref, { (_, flags, info) in
            guard let info = info else { return }
            let reachability = Unmanaged<Reachability>.fromOpaque(info).takeUnretainedValue()
            reachability.reachabilityChanged(flags: flags)
        }, &context)
        
        SCNetworkReachabilitySetDispatchQueue(ref, DispatchQueue.main)
        isRunning = true
    }
    
    func stop() {
        guard let ref = reachabilityRef, isRunning else { return }
        SCNetworkReachabilitySetDispatchQueue(ref, nil)
        isRunning = false
    }
    
    private func reachabilityChanged(flags: SCNetworkReachabilityFlags) {
        if isReachableWithFlags(flags) {
            reachable?()
        } else {
            unreachable?()
        }
    }
    
    private func isReachableWithFlags(_ flags: SCNetworkReachabilityFlags) -> Bool {
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let canConnectAutomatically = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
        let canConnectWithoutUserInteraction = canConnectAutomatically && !flags.contains(.interventionRequired)
        
        return isReachable && (!needsConnection || canConnectWithoutUserInteraction)
    }
}
