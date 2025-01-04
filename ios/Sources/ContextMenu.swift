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
    var currentMenu: UIMenu?
    var menuCallback: ((String) -> Void)?

    @objc public func popup(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(ContextMenuOptions.self)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let menu = self.createMenu(from: args.items) { selectedId in
                invoke.resolve(["id": selectedId])
            }

            // Create a temporary button to present the menu
            let button = UIButton(frame: CGRect.zero)
            button.menu = menu
            button.showsMenuAsPrimaryAction = true

            // Add button temporarily to the view
            if let viewController = self.manager.viewController {
                viewController.view.addSubview(button)

                // Position the menu
                let x = args.x ?? 0
                let y = args.y ?? 0
                button.frame = CGRect(x: x, y: y, width: 1, height: 1)

                // Show menu
                button.sendActions(for: .menuActionTriggered)

                // Remove button after menu disappears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    button.removeFromSuperview()
                }
            }
        }
    }

    private func createMenu(from items: [MenuItem], callback: @escaping (String) -> Void) -> UIMenu
    {
        let menuElements = items.map { item in
            self.createMenuItem(from: item, callback: callback)
        }

        return UIMenu(title: "", children: menuElements)
    }

    private func createMenuItem(from item: MenuItem, callback: @escaping (String) -> Void)
        -> UIMenuElement
    {
        if let subItems = item.subItems, !subItems.isEmpty {
            // Create submenu
            let subMenuElements = subItems.map { subItem in
                self.createMenuItem(from: subItem, callback: callback)
            }
            return UIMenu(title: item.label, children: subMenuElements)
        } else {
            // Create action
            return UIAction(
                title: item.label,
                state: item.selected == true ? .on : .off,
                attributes: item.enabled == false ? .disabled : [],
                handler: { _ in
                    callback(item.id)
                }
            )
        }
    }
}

@_cdecl("init_plugin_context_menu")
func initPlugin() -> Plugin {
    return ContextMenuPlugin()
}
