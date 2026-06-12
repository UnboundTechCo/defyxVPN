import Flutter
import UIKit
import CoreHaptics

class VibrationPlugin: NSObject {
    private var lastVibrationTime: TimeInterval = 0
    private let throttleDuration: TimeInterval = 5.0
    
    private var hapticEngine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    
    override init() {
        super.init()
        setupHapticEngine()
    }
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            supportsHaptics = false
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            supportsHaptics = true
        } catch {
            print("Failed to create haptic engine: \(error)")
            supportsHaptics = false
        }
    }
    
    func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "hasVibrator":
            result(supportsHaptics)
            
        case "vibrate":
            guard let args = call.arguments as? [String: Any],
                  let duration = args["duration"] as? Int else {
                vibrate(duration: 50, result: result)
                return
            }
            vibrate(duration: duration, result: result)
            
        case "cancel":
            cancel(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func canVibrate() -> Bool {
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastVibration = currentTime - lastVibrationTime
        return timeSinceLastVibration >= throttleDuration
    }
    
    private func recordVibration() {
        lastVibrationTime = Date().timeIntervalSince1970
    }
    
    private func vibrate(duration: Int, result: @escaping FlutterResult) {
        guard canVibrate() else {
            print("Vibration throttled")
            result(false)
            return
        }
        
        if supportsHaptics {
            vibrateWithHaptics(duration: duration, result: result)
        } else {
            vibrateWithLegacy(result: result)
        }
    }
    
    private func vibrateWithHaptics(duration: Int, result: @escaping FlutterResult) {
        guard let engine = hapticEngine else {
            vibrateWithLegacy(result: result)
            return
        }
        
        do {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [intensity, sharpness],
                relativeTime: 0,
                duration: TimeInterval(duration) / 1000.0
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            
            try player.start(atTime: CHHapticTimeImmediate)
            
            recordVibration()
            result(true)
        } catch {
            print("Failed to play haptic: \(error)")
            vibrateWithLegacy(result: result)
        }
    }
    
    private func vibrateWithLegacy(result: @escaping FlutterResult) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        recordVibration()
        result(true)
    }
    
    private func cancel(result: @escaping FlutterResult) {
        do {
            try hapticEngine?.stop()
            result(true)
        } catch {
            print("Failed to stop haptic engine: \(error)")
            result(false)
        }
    }
}
