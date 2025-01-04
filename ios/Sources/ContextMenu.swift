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

class ContextMenuPlugin: Plugin {
    var currentMenu: UIAlertController?
    var menuCallback: ((String) -> Void)?

    @objc public func popup(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(ContextMenuOptions.self)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let alertController = UIAlertController(
                title: nil, message: nil, preferredStyle: .actionSheet)

            // Add menu items recursively
            self.addMenuItems(items: args.items, to: alertController) { selectedId in
                invoke.resolve(["id": selectedId])
            }

            // Add cancel action
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

            // Present the alert controller
            if let vc = self.manager.viewController {
                // For iPad, set the source point
                if let popoverController = alertController.popoverPresentationController {
                    popoverController.sourceView = vc.view
                    popoverController.sourceRect = CGRect(
                        x: args.x ?? 0, y: args.y ?? 0, width: 1, height: 1)
                }

                vc.present(alertController, animated: true)
            }
        }
    }

    private func addMenuItems(
        items: [MenuItem],
        to alertController: UIAlertController,
        callback: @escaping (String) -> Void
    ) {
        for item in items {
            if let subItems = item.subItems, !subItems.isEmpty {
                // Create a new action for submenus that presents another alert controller
                let action = UIAlertAction(title: item.label, style: .default) { [weak self] _ in
                    let subMenu = UIAlertController(
                        title: nil, message: nil, preferredStyle: .actionSheet)
                    self?.addMenuItems(items: subItems, to: subMenu, callback: callback)
                    subMenu.addAction(UIAlertAction(title: "Back", style: .cancel))

                    if let vc = self?.manager.viewController {
                        // For iPad, set the source point
                        if let popoverController = subMenu.popoverPresentationController {
                            popoverController.sourceView = vc.view
                            popoverController.sourceRect = vc.view.bounds
                        }

                        vc.present(subMenu, animated: true)
                    }
                }
                action.isEnabled = item.enabled != false
                alertController.addAction(action)
            } else {
                // Add single action
                let action = UIAlertAction(title: item.label, style: .default) { _ in
                    callback(item.id)
                }
                action.isEnabled = item.enabled != false
                alertController.addAction(action)
            }
        }
    }
}

// Tauri requires a top-level C function for plugin init
@_cdecl("init_plugin_context_menu")
func initPlugin() -> Plugin {
    return ContextMenuPlugin()
}
