import Cocoa

class IconManager {
    static func fetchDockItems() -> [DockItem] {
        var items: [DockItem] = []
        
        // 1. Persistent Apps (Section 1)
        var persistentBundleIDs = Set<String>()
        
        if let dockDict = UserDefaults.standard.persistentDomain(forName: "com.apple.dock"),
           let persistentApps = dockDict["persistent-apps"] as? [[String: Any]] {
            
            for appDict in persistentApps {
                if let tileData = appDict["tile-data"] as? [String: Any],
                   let bundleID = tileData["bundle-identifier"] as? String,
                   let label = tileData["file-label"] as? String {
                    
                    persistentBundleIDs.insert(bundleID)
                    
                    // Get Icon
                    var icon: NSImage?
                    var appURL: URL?
                    
                    if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                        appURL = path
                        icon = NSWorkspace.shared.icon(forFile: path.path)
                    } else {
                        // Fallback icon if app not found
                        icon = NSWorkspace.shared.icon(forFileType: "app")
                    }
                    
                    if let icon = icon {
                        items.append(DockItem(type: .persistentApp(bundleIdentifier: bundleID, name: label, url: appURL),
                                              icon: icon,
                                              name: label))
                    }
                }
            }
        }
        
        // Divider 1
        items.append(DockItem(type: .divider, icon: NSImage(), name: ""))
        
        // 2. Running Apps (Section 2)
        // Only those NOT in persistent list
        // Only those NOT in persistent list
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            if app.activationPolicy == .regular {
                if let bundleID = app.bundleIdentifier {
                    if !persistentBundleIDs.contains(bundleID) {
                        if let icon = app.icon {
                            items.append(DockItem(type: .runningApp(app),
                                                  icon: icon,
                                                  name: app.localizedName ?? "App"))
                        }
                    }
                }
            }
        }
        
        // Divider 2 (Only if we added running apps, or always? Dock usually always has a divider before Trash)
        // Actually, the user asked for 3 groups. Even if group 2 is empty, we might want the divider or maybe merge?
        // Let's add the divider.
        items.append(DockItem(type: .divider, icon: NSImage(), name: ""))
        
        // 3. Downloads & Trash (Section 3)
        
        // Downloads
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let downloadsIcon = NSWorkspace.shared.icon(forFile: downloadsURL.path)
        items.append(DockItem(type: .folder(url: downloadsURL, name: "Downloads"),
                              icon: downloadsIcon,
                              name: "Downloads"))
        
        // Trash
        if let trashIcon = NSImage(named: NSImage.trashEmptyName) {
            items.append(DockItem(type: .trash, icon: trashIcon, name: "Trash"))
        }
        
        return items
    }
}
