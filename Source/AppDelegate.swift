//
//  AppDelegate.swift
//  clipboard-swift
//
//  Created by Ace ♠️ on 09/06/2025.
//

import Cocoa
import Carbon
import ServiceManagement
import CoreServices // Import for LSSharedFileList

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var clipboardHistoryViewController: ClipboardHistoryViewController?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyEventHandler: EventHandlerRef?
    private var outsideClickGlobalMonitor: Any?
    private var outsideClickLocalMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var isClosingForDrag = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide the dock icon to make it a menu bar app
        NSApp.setActivationPolicy(.accessory)

        // Close any default storyboard windows so they never steal focus from the popover
        for window in NSApp.windows {
            window.close()
        }

        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            if let iconImage = NSImage(named: "TrayIcon") {
                iconImage.isTemplate = false
                button.image = iconImage
                button.imagePosition = .imageOnly
                button.imageScaling = .scaleProportionallyUpOrDown
            } else {
                button.title = "📋"
            }
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        // Initialize the ClipboardHistoryViewController
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        clipboardHistoryViewController = storyboard.instantiateController(withIdentifier: "ClipboardHistoryVC") as? ClipboardHistoryViewController

        // Create and configure the popover
        // Use .applicationDefined instead of .transient so AppKit does not prematurely dismiss
        // the popover during the app activation transition triggered by a global hotkey.
        popover = NSPopover()
        popover?.contentViewController = clipboardHistoryViewController
        popover?.behavior = .applicationDefined
        popover?.animates = true
        popover?.delegate = self

        // Pre-load the view controller's view to ensure clipboard monitoring starts immediately
        _ = clipboardHistoryViewController?.view

        // Register the global shortcut (Control + V)
        setupGlobalShortcut()

        // Set up auto-launch on startup
        setupAutoLaunch()
    }

    func setupGlobalShortcut() {
        guard hotKeyRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData, let event = event else {
                    return OSStatus(eventNotHandledErr)
                }
                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if err == noErr && hotKeyID.id == 1 {
                    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                    DispatchQueue.main.async {
                        appDelegate.togglePopover(nil)
                    }
                    return noErr
                }
                return OSStatus(eventNotHandledErr)
            },
            1,
            &eventType,
            selfPtr,
            &hotKeyEventHandler
        )

        guard status == noErr else { return }

        // "CLPY" signature
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C5059), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(relativeTo: button)
        }
    }

    private func showPopover(relativeTo button: NSStatusBarButton) {
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmost
        }

        clipboardHistoryViewController?.refreshClipboardIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func closePopover(sender: Any?) {
        guard popover?.isShown == true else { return }
        popover?.performClose(sender)
    }

    private func startOutsideClickMonitors() {
        stopOutsideClickMonitors()

        outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.closePopover(sender: nil)
        }

        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self = self, let popover = self.popover, popover.isShown else {
                return event
            }
            if event.type == .keyDown {
                // Close on Escape key (keyCode 53)
                if event.keyCode == 53 {
                    self.closePopover(sender: nil)
                    return nil
                }
                return event
            }
            if let popoverWindow = popover.contentViewController?.view.window,
               let statusWindow = self.statusItem?.button?.window {
                if event.window != popoverWindow && event.window != statusWindow {
                    self.closePopover(sender: nil)
                }
            }
            return event
        }
    }

    private func stopOutsideClickMonitors() {
        if let monitor = outsideClickGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickGlobalMonitor = nil
        }
        if let monitor = outsideClickLocalMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickLocalMonitor = nil
        }
    }

    // MARK: - Auto Launch Setup
    
    func setupAutoLaunch() {
        // Enable auto-launch immediately without asking the user
        if !isLaunchAtLoginEnabled() {
            setLaunchAtLogin(true)
            print("Auto-launch enabled for Clippy")
        } else {
            print("Auto-launch was already enabled.")
        }
    }
    
    func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            // Use SMAppService for macOS 13+
            do {
                let service = SMAppService.mainApp
                if enabled {
                    if service.status == .notRegistered {
                        try service.register()
                        print("Successfully registered app for auto-launch")
                    } else {
                        print("App already registered for auto-launch")
                    }
                } else {
                    try service.unregister()
                    print("Successfully unregistered app from auto-launch")
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") auto-launch: \(error)")
            }
        } else {
            // Fallback for older macOS versions using LSSharedFileList
            if enabled {
                addToLoginItems()
            } else {
                removeFromLoginItems()
            }
        }
    }
    
    private func addToLoginItems() {
        let appURL = Bundle.main.bundleURL
        
        // Use LSSharedFileList for older macOS versions
        let fileList = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeUnretainedValue(), nil)
        guard let loginItems = fileList?.takeRetainedValue() else {
            print("Failed to create login items list.")
            return
        }
        
        LSSharedFileListInsertItemURL(
            loginItems,
            kLSSharedFileListItemLast.takeUnretainedValue(),
            nil,
            nil,
            appURL as CFURL,
            nil,
            nil
        )
        print("Added to login items using LSSharedFileList")
    }
    
    private func removeFromLoginItems() {
        let appURL = Bundle.main.bundleURL
        
        let fileList = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeUnretainedValue(), nil)
        guard let loginItems = fileList?.takeRetainedValue() else {
            print("Failed to create login items list for removal.")
            return
        }
        
        guard let snapshot = LSSharedFileListCopySnapshot(loginItems, nil) else {
            print("Failed to get login items snapshot.")
            return
        }
        
        let loginItemsArray = snapshot.takeRetainedValue() as! [LSSharedFileListItem]
        
        for item in loginItemsArray {
            var resolutionRef: Unmanaged<CFURL>?
            
            if LSSharedFileListItemResolve(item, 0, &resolutionRef, nil) == noErr,
               let resolvedURL = resolutionRef?.takeRetainedValue(),
               (resolvedURL as URL) == appURL {
                LSSharedFileListItemRemove(loginItems, item)
                print("Removed from login items using LSSharedFileList")
                break
            }
        }
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            return service.status == .enabled
        } else {
            // Check using LSSharedFileList for older versions
            let appURL = Bundle.main.bundleURL
            
            let fileList = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeUnretainedValue(), nil)
            guard let loginItems = fileList?.takeRetainedValue() else { return false }
            
            guard let snapshot = LSSharedFileListCopySnapshot(loginItems, nil) else { return false }
            let loginItemsArray = snapshot.takeRetainedValue() as! [LSSharedFileListItem]
            
            for item in loginItemsArray {
                var resolutionRef: Unmanaged<CFURL>?
                
                if LSSharedFileListItemResolve(item, 0, &resolutionRef, nil) == noErr,
                   let resolvedURL = resolutionRef?.takeRetainedValue(),
                   (resolvedURL as URL) == appURL {
                    return true
                }
            }
            return false
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        stopOutsideClickMonitors()
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let hotKeyEventHandler = hotKeyEventHandler {
            RemoveEventHandler(hotKeyEventHandler)
            self.hotKeyEventHandler = nil
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - NSPopoverDelegate Methods

    func popoverWillShow(_ notification: Notification) {
        clipboardHistoryViewController?.refreshClipboardIfNeeded()
    }

    func popoverDidShow(_ notification: Notification) {
        if let popoverWindow = popover?.contentViewController?.view.window {
            popoverWindow.makeKeyAndOrderFront(nil)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDrag),
            name: NSNotification.Name("ClippyItemDidBeginDrag"),
            object: nil
        )
        startOutsideClickMonitors()
    }

    @objc func handleDrag(_ notification: Notification) {
        isClosingForDrag = true
        closePopover(sender: nil)
    }

    func popoverWillClose(_ notification: Notification) {
        stopOutsideClickMonitors()
    }

    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitors()
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("ClippyItemDidBeginDrag"),
            object: nil
        )
        if !isClosingForDrag, let previousApp = previousApp, !previousApp.isTerminated {
            previousApp.activate(options: [])
        }
        isClosingForDrag = false
        previousApp = nil
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        return true
    }
}

