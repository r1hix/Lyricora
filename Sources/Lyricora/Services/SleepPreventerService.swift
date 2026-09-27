import Foundation
import IOKit.pwr_mgt
import Observation

@Observable
@MainActor
public final class SleepPreventerService {
    public static let shared = SleepPreventerService()
    
    private let screenAwakeKey = "lyricora.power.keepScreenAwake"
    @ObservationIgnored private var assertionID: IOPMAssertionID = 0
    
    public var isScreenAwakeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isScreenAwakeEnabled, forKey: screenAwakeKey)
            applyScreenAwakeState()
        }
    }
    
    private init() {
        self.isScreenAwakeEnabled = UserDefaults.standard.bool(forKey: screenAwakeKey)
        if self.isScreenAwakeEnabled {
            applyScreenAwakeState()
        }
    }
    
    public func toggleScreenAwake() {
        isScreenAwakeEnabled.toggle()
    }
    
    private func applyScreenAwakeState() {
        if isScreenAwakeEnabled {
            enableScreenAwake()
        } else {
            disableScreenAwake()
        }
    }
    
    private func enableScreenAwake() {
        guard assertionID == 0 else { return }
        
        // kIOPMAssertionTypePreventUserIdleDisplaySleep prevents the display from sleeping
        // without disabling ambient light sensor (auto-brightness) or system thermal throttling.
        // It operates identically to KeepingYouAwake and caffeinate -d.
        let assertionType = kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
        let reason = "Lyricora: Keep Screen Awake" as CFString
        
        let result = IOPMAssertionCreateWithName(
            assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        
        if result == kIOReturnSuccess {
            print("[SleepPreventerService] Screen awake assertion successfully acquired (ID: \(assertionID))")
        } else {
            print("[SleepPreventerService] Failed to acquire assertion: \(result)")
            assertionID = 0
        }
    }
    
    public func disableScreenAwake() {
        guard assertionID != 0 else { return }
        let result = IOPMAssertionRelease(assertionID)
        if result == kIOReturnSuccess {
            print("[SleepPreventerService] Screen awake assertion released (restoring standard power settings)")
        }
        assertionID = 0
    }
    
    public func cleanup() {
        disableScreenAwake()
    }
}
