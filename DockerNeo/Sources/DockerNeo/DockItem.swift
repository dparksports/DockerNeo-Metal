import Cocoa

enum DockItemType: Equatable {
    case persistentApp(bundleIdentifier: String, name: String, url: URL?)
    case runningApp(NSRunningApplication)
    case divider
    case folder(url: URL, name: String)
    case trash
    
    static func == (lhs: DockItemType, rhs: DockItemType) -> Bool {
        switch (lhs, rhs) {
        case (.persistentApp(let b1, _, _), .persistentApp(let b2, _, _)):
            return b1 == b2
        case (.runningApp(let a1), .runningApp(let a2)):
            return a1 == a2
        case (.divider, .divider):
            return true
        case (.folder(let u1, _), .folder(let u2, _)):
            return u1 == u2
        case (.trash, .trash):
            return true
        default:
            return false
        }
    }
}

struct DockItem {
    let type: DockItemType
    let icon: NSImage
    let name: String
}
