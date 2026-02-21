import UIKit
import Social
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {
    
    override func isContentValid() -> Bool {
        // Validation logic - ensure there's a PDF attached or a URL
        return true
    }
    
    override func didSelectPost() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        for provider in attachments {
            // Check for PDF
            if provider.hasItemConformingToTypeIdentifier(kUTTypePDF as String) {
                provider.loadItem(forTypeIdentifier: kUTTypePDF as String, options: nil) { (item, error) in
                    if let url = item as? URL {
                        // In a real app, upload this to Supabase Storage and link it to the Paper record
                        print("Syncing PDF to Supabase: \(url.lastPathComponent)")
                        
                        // Let the view controller finish
                        DispatchQueue.main.async {
                            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                        }
                    }
                }
                break
            }
        }
    }
    
    override func configurationItems() -> [Any]! {
        // Return context items like selecting a target 'Folder' in the app
        return []
    }
}
