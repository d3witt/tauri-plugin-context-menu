import SwiftRs
import Tauri
import UIKit
import WebKit

struct MenuItem: Decodable {
    let id: String
    let label: String
    var enabled: Bool?
    var selected: Bool?
    var subItems: [MenuItem]?
}

struct ContextMenuOptions: Decodable {
    let items: [MenuItem]
    var x: Double?
    var y: Double?
}

// Require iOS 14+ for the entire class
@available(iOS 14.0, *)
class ContextMenuPlugin: Plugin {
    var currentMenu: UIMenu?
    var menuCallback: ((String) -> Void)?

    @objc public func popup(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(ContextMenuOptions.self)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Build the menu
            let menu = self.createMenu(from: args.items) { selectedId in
                invoke.resolve(["id": selectedId])
            }

            // Create a temporary button to present the menu
            let button = UIButton(frame: .zero)
            button.menu = menu
            button.showsMenuAsPrimaryAction = true

            // Attach button to the view, position, and show
            if let vc = self.manager.viewController {
                vc.view.addSubview(button)
                let x = args.x ?? 0
                let y = args.y ?? 0
                button.frame = CGRect(x: x, y: y, width: 1, height: 1)
                button.sendActions(for: .menuActionTriggered)

                // Remove after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    button.removeFromSuperview()
                }
            }
        }
    }

    private func createMenu(
        from items: [MenuItem],
        callback: @escaping (String) -> Void
    ) -> UIMenu {
        let menuElements = items.map {
            createMenuItem(from: $0, callback: callback)
        }
        return UIMenu(title: "", children: menuElements)
    }

    private func createMenuItem(
        from item: MenuItem,
        callback: @escaping (String) -> Void
    ) -> UIMenuElement {
        if let subItems = item.subItems, !subItems.isEmpty {
            // Create nested submenu
            let children = subItems.map { createMenuItem(from: $0, callback: callback) }
            return UIMenu(title: item.label, children: children)
        } else {
            // Single action
            return UIAction(
                title: item.label,
                attributes: item.enabled == false ? .disabled : [],
                state: item.selected == true ? .on : .off
            ) { _ in
                callback(item.id)
            }
        }
    }
}

// Tauri requires a top-level C function for plugin init
@_cdecl("init_plugin_context_menu")
func initPlugin() -> Plugin {
    // If you truly only support iOS 14+, just return directly.
    // If someone runs iOS 13, the app will refuse to install or crash on launch.
    return ContextMenuPlugin()
}
