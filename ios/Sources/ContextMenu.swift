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

            // If running on iOS 14 or newer, use UIMenu-based context menus:
            if #available(iOS 14.0, *) {
                self.presentContextMenuiOS14(args: args) { selectedId in
                    invoke.resolve(["id": selectedId])
                }
            } else {
                // Otherwise (iOS 13 and below), fall back to an action-sheet style menu:
                self.presentFallbackAlertController(args: args) { selectedId in
                    invoke.resolve(["id": selectedId])
                }
            }
        }
    }

    // MARK: - iOS 14 code

    @available(iOS 14.0, *)
    private func presentContextMenuiOS14(
        args: ContextMenuOptions,
        selectionHandler: @escaping (String) -> Void
    ) {
        let menu = createMenu(from: args.items, callback: selectionHandler)

        // Create a temporary button to present the menu
        let button = UIButton(frame: .zero)
        button.menu = menu
        button.showsMenuAsPrimaryAction = true

        // Add button temporarily to the view
        if let viewController = manager.viewController {
            viewController.view.addSubview(button)

            // Position the menu
            let x = args.x ?? 0
            let y = args.y ?? 0
            button.frame = CGRect(x: x, y: y, width: 1, height: 1)

            // Show menu
            button.sendActions(for: .menuActionTriggered)

            // Remove button after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                button.removeFromSuperview()
            }
        }
    }

    // MARK: - iOS 13 fallback

    private func presentFallbackAlertController(
        args: ContextMenuOptions,
        selectionHandler: @escaping (String) -> Void
    ) {
        guard let viewController = manager.viewController else {
            return
        }

        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        for menuItem in args.items {
            // Recursively add actions for subItems, if any
            addAction(for: menuItem, to: alert, selectionHandler: selectionHandler)
        }

        // Positioning the action sheet near x,y in iPad can require a popover sourceRect/sourceView.
        // For simplicity, we’ll just position it from the center or top of the screen if we can.
        if let popover = alert.popoverPresentationController {
            popover.sourceView = viewController.view
            // If you want to position near x,y, specify the rect here:
            let x = CGFloat(args.x ?? 0)
            let y = CGFloat(args.y ?? 0)
            popover.sourceRect = CGRect(x: x, y: y, width: 1, height: 1)
        }

        viewController.present(alert, animated: true, completion: nil)
    }

    /// Recursively adds a UIAlertAction (or sub-alert) for the given MenuItem.
    private func addAction(
        for item: MenuItem,
        to alert: UIAlertController,
        selectionHandler: @escaping (String) -> Void
    ) {
        // If the item has subItems, one approach is:
        // 1) Create another UIAlertController on tap.
        // 2) Present that sub-menu.
        // For simplicity, we’ll flatten them in the alert.
        // Real code might do something more sophisticated.

        if let subItems = item.subItems, !subItems.isEmpty {
            // Flatten sub-items as more actions
            for subItem in subItems {
                addAction(for: subItem, to: alert, selectionHandler: selectionHandler)
            }
        } else {
            // Just a normal item
            let action = UIAlertAction(
                title: item.label,
                style: .default
            ) { _ in
                selectionHandler(item.id)
            }

            // Disable if item.enabled == false
            action.isEnabled = (item.enabled ?? true)

            alert.addAction(action)
        }
    }

    // MARK: - Create UIMenu/Actions

    /// Creates a top-level UIMenu using UIAction or nested UIMenus.
    @available(iOS 14.0, *)
    private func createMenu(
        from items: [MenuItem],
        callback: @escaping (String) -> Void
    ) -> UIMenu {
        let menuElements = items.map { item in
            self.createMenuItem(from: item, callback: callback)
        }
        return UIMenu(title: "", children: menuElements)
    }

    @available(iOS 14.0, *)
    private func createMenuItem(
        from item: MenuItem,
        callback: @escaping (String) -> Void
    ) -> UIMenuElement {
        if let subItems = item.subItems, !subItems.isEmpty {
            // Create submenu
            let subMenuElements = subItems.map { subItem in
                self.createMenuItem(from: subItem, callback: callback)
            }
            return UIMenu(title: item.label, children: subMenuElements)
        } else {
            // Create action (UIAction)
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

// Must remain a top-level function for Swift + Tauri bridging:
@_cdecl("init_plugin_context_menu")
func initPlugin() -> Plugin {
    return ContextMenuPlugin()
}
