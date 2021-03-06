/*
	Abstract:
	Model class representing a single call
 */
import Foundation

@available(iOS 10.0, *)
final class CDVCall {
    
    // MARK: Metadata Properties
    
    let uuid: UUID
    let isOutgoing: Bool
    var handle: String?
    
    // MARK: Call State Properties
    
    var connectingDate: Date? {
        didSet {
            stateDidChange?()
            hasStartedConnectingDidChange?()
        }
    }
    var connectDate: Date? {
        didSet {
            stateDidChange?()
            hasConnectedDidChange?()
        }
    }
    var endDate: Date? {
        didSet {
            stateDidChange?()
            hasEndedDidChange?()
        }
    }
    var isOnHold = false {
        didSet {
            stateDidChange?()
        }
    }
    
    // MARK: State change callback blocks
    
    var stateDidChange: (() -> Void)?
    var hasStartedConnectingDidChange: (() -> Void)?
    var hasConnectedDidChange: (() -> Void)?
    var hasEndedDidChange: (() -> Void)?
    
    // MARK: Derived Properties
    
    var hasStartedConnecting: Bool {
        get {
            return connectingDate != nil
        }
        set {
            connectingDate = newValue ? Date() : nil
        }
    }
    var hasConnected: Bool {
        get {
            return connectDate != nil
        }
        set {
            connectDate = newValue ? Date() : nil
        }
    }
    var hasEnded: Bool {
        get {
            return endDate != nil
        }
        set {
            endDate = newValue ? Date() : nil
        }
    }
    var duration: TimeInterval {
        guard let connectDate = connectDate else {
            return 0
        }
        
        return Date().timeIntervalSince(connectDate)
    }
    
    // MARK: Initialization
    
    init(uuid: UUID, isOutgoing: Bool = false) {
        self.uuid = uuid
        self.isOutgoing = isOutgoing
    }
    
    // MARK: Actions
    
    func startCDVCall(_ completion: ((_ success: Bool) -> Void)?) {
        // Simulate the call starting successfully
        completion?(true)
        
        hasStartedConnecting = true
    }
    
    func connectedCDVCall() {
        // Call has connected
        hasConnected = true
    }
    
    func answerCDVCall() {
        // call is answered, start connecting
        hasStartedConnecting = true
    }
    
    func endCDVCall() {
        /*
         Simulate the end taking effect immediately, since
         the example app is not backed by a real network service
         */
        hasEnded = true
    }
    
}
