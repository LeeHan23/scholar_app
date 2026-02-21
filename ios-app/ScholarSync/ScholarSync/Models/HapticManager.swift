import UIKit
import CoreHaptics

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Used when a barcode/DOI is successfully scanned
    func scanSuccess() {
        notification(type: .success)
    }
    
    /// Used when the scanner detects a partial match or is analyzing
    func scanTick() {
        impact(style: .light)
    }
}
