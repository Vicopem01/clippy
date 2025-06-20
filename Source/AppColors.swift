//
//  AppColors.swift
//  clipboard-swift
//
//  Created by GitHub Copilot on 09/06/2025.
//

import Cocoa

struct AppColors {
    // From modal.css body background-color: rgba(42, 42, 46, 0.98)
    static let popoverBackground = NSColor(calibratedRed: 42/255, green: 42/255, blue: 46/255, alpha: 0.98)
    // From modal.css .modal-header background-color: #383840
    static let headerBackground = NSColor(calibratedRed: 56/255, green: 56/255, blue: 64/255, alpha: 1.0)
    // From modal.css .modal-header color: #b0b0b0 (for title)
    static let headerTitleText = NSColor(calibratedRed: 176/255, green: 176/255, blue: 176/255, alpha: 1.0)
    // From modal.css .clear-button color: #888
    static let headerClearButtonText = NSColor(calibratedRed: 136/255, green: 136/255, blue: 136/255, alpha: 1.0)
    // From modal.css .clear-button:hover color: #e0e0e0
    static let headerClearButtonHoverText = NSColor(calibratedRed: 224/255, green: 224/255, blue: 224/255, alpha: 1.0)
    // From modal.css .clear-button:hover background-color: rgba(255, 255, 255, 0.1)
    static let headerClearButtonHoverBackground = NSColor(deviceWhite: 1.0, alpha: 0.1)
    // From modal.css body color: #e0e0e0
    static let primaryText = NSColor(calibratedRed: 224/255, green: 224/255, blue: 224/255, alpha: 1.0) // #e0e0e0
    // From modal.css .history-item border-bottom: 1px solid #444
    static let itemBorder = NSColor(calibratedRed: 68/255, green: 68/255, blue: 68/255, alpha: 1.0) // #444444
    // From modal.css .history-item:hover background-color: #3d3c45
    static let itemHoverBackground = NSColor(calibratedRed: 61/255, green: 60/255, blue: 69/255, alpha: 1.0) // #3d3c45
    // From modal.css .history-item.active background-color: #4b4b61
    static let itemSelectedBackground = NSColor(calibratedRed: 75/255, green: 75/255, blue: 97/255, alpha: 1.0) // #4b4b61
    // From modal.css .empty-message color: #888
    static let emptyMessageText = NSColor(calibratedRed: 136/255, green: 136/255, blue: 136/255, alpha: 1.0) // #888888
    // From modal.css .modal-footer color: #777
    static let footerText = NSColor(calibratedRed: 119/255, green: 119/255, blue: 119/255, alpha: 1.0) // #777777
    // From modal.css .author-link color: #8a70c2
    static let authorLink = NSColor(calibratedRed: 138/255, green: 112/255, blue: 194/255, alpha: 1.0) // #8a70c2
    // From modal.css .draggable::after color: #8a8aad
    static let dragHandle = NSColor(calibratedRed: 138/255, green: 138/255, blue: 173/255, alpha: 1.0) // #8a8aad
    // From modal.css scrollbar-color: #666 #2a2a2e (thumb and track)
    static let scrollBarThumb = NSColor(calibratedRed: 102/255, green: 102/255, blue: 102/255, alpha: 1.0) // #666666
    static let scrollBarTrack = NSColor(calibratedRed: 42/255, green: 42/255, blue: 46/255, alpha: 1.0) // #2a2a2e (same as popover bg)
}
