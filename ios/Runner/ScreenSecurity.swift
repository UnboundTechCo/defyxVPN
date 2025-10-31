import Foundation
import Flutter
import UIKit

class ScreenSecurity {
    static func enableScreenSecurity() {
        DispatchQueue.main.async {
            // Method 1: Adjust window level to hide content from screenshots
            if let window = UIApplication.shared.delegate?.window as? UIWindow {
                window.windowLevel = UIWindow.Level.statusBar + 1
            }
            
            // Method 2: For newer iOS versions with scene-based apps
            if #available(iOS 13.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    for window in windowScene.windows {
                        window.windowLevel = UIWindow.Level.statusBar + 1
                    }
                }
            }
            
            // Method 3: Add a secure overlay view (additional protection)
            if let window = UIApplication.shared.delegate?.window as? UIWindow {
                // Remove any existing overlay first
                if let existingOverlay = window.viewWithTag(9999) {
                    existingOverlay.removeFromSuperview()
                }
                
                let overlayView = UIView()
                overlayView.backgroundColor = UIColor.black
                overlayView.tag = 9999 // Tag for easy identification
                overlayView.frame = window.bounds
                overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                
                window.addSubview(overlayView)
                window.bringSubviewToFront(overlayView)
            }
            
            print("Screen security enabled")
        }
    }
    
    static func disableScreenSecurity() {
        DispatchQueue.main.async {
            // Restore normal window level
            if let window = UIApplication.shared.delegate?.window as? UIWindow {
                window.windowLevel = UIWindow.Level.normal
            }
            
            // For newer iOS versions with scene-based apps
            if #available(iOS 13.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    for window in windowScene.windows {
                        window.windowLevel = UIWindow.Level.normal
                    }
                }
            }
            
            // Remove overlay view if it exists
            if let window = UIApplication.shared.delegate?.window as? UIWindow {
                if let overlayView = window.viewWithTag(9999) {
                    overlayView.removeFromSuperview()
                }
            }
            
            print("Screen security disabled")
        }
    }
}