//
//  AppDelegate.swift
//  clipboard-swift
//
//  Created by Ace ♠️ on 09/06/2025.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate { // Added NSPopoverDelegate

    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var clipboardHistoryViewController: ClipboardHistoryViewController?
    var eventMonitor: Any? // For global keyboard shortcut

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide the dock icon to make it a menu bar app
        NSApp.setActivationPolicy(.accessory) // Ensure this is early

        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Attempt to load icon.png from the app bundle
            if let iconImage = NSImage(named: "TrayIcon") { // Assumes "icon.png" is in Assets.xcassets as "icon"
                iconImage.isTemplate = false // Use false for color icons
                button.image = iconImage
                button.imagePosition = .imageOnly // Ensure only image is shown
                button.imageScaling = .scaleProportionallyUpOrDown // Ensure aspect ratio is maintained
            } else {
                button.title = "📋" // Fallback to emoji if icon isn't found
                print("Failed to load TrayIcon from Assets.xcassets, using fallback emoji.")
            }
            button.action = #selector(togglePopover(_:))
        }

        // Initialize the ClipboardHistoryViewController
        // Assuming it's in Main.storyboard and has a Storyboard ID "ClipboardHistoryVC"
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        clipboardHistoryViewController = storyboard.instantiateController(withIdentifier: "ClipboardHistoryVC") as? ClipboardHistoryViewController

        // Create and configure the popover
        popover = NSPopover()
        popover?.contentViewController = clipboardHistoryViewController
        popover?.behavior = .transient // Revert to .transient
        popover?.animates = true
        popover?.delegate = self // Set the delegate

        // Pre-load the view controller's view to ensure it's ready
        clipboardHistoryViewController?.loadViewIfNeeded()

        // Attempt to register the global shortcut
        setupGlobalShortcut()

        // Add an observer to re-check permissions when the app becomes active
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    @objc func appDidBecomeActive() {
        // Re-check permissions and set up the shortcut if needed
        if eventMonitor == nil {
            setupGlobalShortcut()
        }
    }

    func setupGlobalShortcut() {
        // Check for accessibility permissions before setting up the shortcut
        if checkAccessibilityPermissions() {
            // Add global event monitor for keyboard shortcuts if it doesn't exist
            if eventMonitor == nil {
                eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    print("Global key down event: keyCode \(event.keyCode), modifiers \(event.modifierFlags), characters: \(event.characters ?? "nil")")
                    // Check for Control + V
                    if event.modifierFlags.contains(.control) && event.keyCode == 0x09 { // kVK_ANSI_V
                        print("Control+V detected, toggling popover.")
                        self?.togglePopover(nil)
                    }
                }
            }
        } else {
            // Permissions are not granted
            print("Accessibility permissions not granted. Global shortcut disabled.")
        }
    }

    func checkAccessibilityPermissions() -> Bool {
        // Check if the app is already trusted
        if AXIsProcessTrusted() {
            print("Accessibility permissions are already granted.")
            return true
        }

        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isAccessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        if isAccessibilityEnabled {
            print("Accessibility permissions have been granted.")
        } else {
            print("Accessibility permissions are not granted. Please grant them in System Settings.")
            // The prompt is shown by the system automatically. We can also guide the user.
            let alert = NSAlert()
            alert.messageText = "Enable Accessibility for Clippy"
            alert.informativeText = "Clippy needs accessibility permissions to use global keyboard shortcuts. Please grant access in System Settings > Privacy & Security > Accessibility."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        return isAccessibilityEnabled
    }

    @objc func togglePopover(_ sender: Any?) {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                print("Popover is shown, closing it.")
                popover?.performClose(sender)
            } else {
                print("Popover is not shown, showing it.")
                NSApp.activate(ignoringOtherApps: true) // Activate app before showing popover
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Further actions like making key window will be handled in popoverDidShow
            }
        }
    }

    // Add this new method to explicitly close the popover
    func closePopover(sender: Any?) {
        popover?.performClose(sender)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        // Remove the event monitor when the application terminates
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - NSPopoverDelegate Methods

    func popoverWillShow(_ notification: Notification) {
        print("Popover will show.")
        // You could, for example, refresh content here if needed
        // clipboardHistoryViewController?.checkClipboard() // If you want to refresh on every show
    }

    func popoverDidShow(_ notification: Notification) {
        print("Popover did show. Making its window key and activating app.")
        if let popoverWindow = popover?.contentViewController?.view.window {
            if !popoverWindow.isKeyWindow {
                popoverWindow.makeKeyAndOrderFront(nil)
                print("Popover window made key and ordered front.")
            }
            // Add observer for drag events
            NotificationCenter.default.addObserver(self, selector: #selector(handleDrag), name: NSNotification.Name("ClippyItemDidBeginDrag"), object: nil)
        } else {
            print("Popover window not found to make key in popoverDidShow.")
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func handleDrag(_ notification: Notification) {
        print("Drag detected, closing popover.")
        closePopover(sender: nil)
    }

    func popoverWillClose(_ notification: Notification) {
        print("Popover will close.")
    }

    func popoverDidClose(_ notification: Notification) {
        print("Popover did close.")
        // Remove drag observer
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ClippyItemDidBeginDrag"), object: nil)
        // When the popover closes, hide the app to return focus to the last active application.
        // This allows the global shortcut to work again immediately.
        NSApp.hide(nil)
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        print("popoverShouldClose called.")
        // For .transient behavior, returning true allows it to close when focus is lost (e.g., clicking outside).
        return true
    }

    // Remove or comment out popoverDidResignKey as it's less relevant for .transient
    // func popoverDidResignKey(_ popover: NSPopover) {
    //     print("popoverDidResignKey called. Popover is no longer key.")
    //     // With .transient, the system handles closing when it resigns key due to outside click.
    // }

    // This method can be used to detach the popover from its positioning view when it closes,
    // which can sometimes help with issues if the positioning view is destroyed.
    // func popoverDidDetach(_ popover: NSPopover) {
    // print("Popover did detach.")
    // }
}

