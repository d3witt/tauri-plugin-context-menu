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

        // Move to the main thread for UI operations
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if #available(iOS 14.0, *) {
                // Use iOS 14 approach with UIMenu
                self.presentContextMenuiOS14(args: args) { selectedId in
                    invoke.resolve(["id": selectedId])
                }
            } else {
                // Fallback for iOS 13 and below
                self.presentFallbackAlertController(args: args) { selectedId in
                    invoke.resolve(["id": selectedId])
                }
            }
        }
    }

    // MARK: - iOS 14+ approach using UIMenu

    @available(iOS 14.0, *)
    private func presentContextMenuiOS14(
        args: ContextMenuOptions, selectionHandler: @escaping (String) -> Void
    ) {
        let menu = createMenu(from: args.items, callback: selectionHandler)

        // Create a temporary button to present the menu
        let button = UIButton(frame: .zero)
        button.menu = menu  // iOS 14 only
        button.showsMenuAsPrimaryAction = true  // iOS 14 only

        // Add the button (invisible, 1x1) to the view
        if let viewController = self.manager.viewController {
            viewController.view.addSubview(button)

            // Position the menu
            let x = args.x ?? 0
            let y = args.y ?? 0
            button.frame = CGRect(x: x, y: y, width: 1, height: 1)

            // Programmatically show the menu
            button.sendActions(for: .menuActionTriggered)  // iOS 14 only

            // Remove button after menu is triggered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                button.removeFromSuperview()
            }
        }
    }

    // MARK: - iOS 13 fallback using UIAlertController (action sheet)

    private func presentFallbackAlertController(
        args: ContextMenuOptions, selectionHandler: @escaping (String) -> Void
    ) {
        guard let viewController = self.manager.viewController else { return }

        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Build the actions from your MenuItem list
        for item in args.items {
            addAlertActions(for: item, to: alert, selectionHandler: selectionHandler)
        }

        // For iPad, we need to configure popoverPresentationController
        if let popover = alert.popoverPresentationController {
            popover.sourceView = viewController.view
            // Position near x,y if provided
            let x = CGFloat(args.x ?? 0)
            let y = CGFloat(args.y ?? 0)
            popover.sourceRect = CGRect(x: x, y: y, width: 1, height: 1)
        }

        viewController.present(alert, animated: true, completion: nil)
    }

    /// Recursively add sub-items as separate actions.
    private func addAlertActions(
        for item: MenuItem, to alert: UIAlertController,
        selectionHandler: @escaping (String) -> Void
    ) {
        // If the item has subItems, you can flatten them or nest them in another alert.
        // Here we simply flatten them for simplicity.
        if let subItems = item.subItems, !subItems.isEmpty {
            for subItem in subItems {
                addAlertActions(for: subItem, to: alert, selectionHandler: selectionHandler)
            }
        } else {
            // Regular item with no sub-items
            let action = UIAlertAction(title: item.label, style: .default) { _ in
                selectionHandler(item.id)
            }
            // Enable or disable
            action.isEnabled = (item.enabled ?? true)

            alert.addAction(action)
        }
    }

    // MARK: - Helpers to create UIMenu / UIAction for iOS 14

    @available(iOS 14.0, *)
    private func createMenu(from items: [MenuItem], callback: @escaping (String) -> Void) -> UIMenu
    {
        let elements = items.map { createMenuItem(from: $0, callback: callback) }
        return UIMenu(title: "", children: elements)
    }

    @available(iOS 14.0, *)
    private func createMenuItem(from item: MenuItem, callback: @escaping (String) -> Void)
        -> UIMenuElement
    {
        if let subItems = item.subItems, !subItems.isEmpty {
            // Create a submenu if there are children
            let subElements = subItems.map { createMenuItem(from: $0, callback: callback) }
            return UIMenu(title: item.label, children: subElements)
        } else {
            // Create a single action
            return UIAction(
                title: item.label,
                // NOTE: 'attributes' must come before 'state'
                attributes: item.enabled == false ? .disabled : [],
                state: item.selected == true ? .on : .off,
                handler: { _ in
                    callback(item.id)
                }
            )
        }
    }
}

// Tauri requires a C-compatible symbol for plugin initialization
@_cdecl("init_plugin_context_menu")
func initPlugin() -> Plugin {
    return ContextMenuPlugin()
}
