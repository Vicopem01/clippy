//
//  ClipboardTableRowView.swift
//  clipboard-swift
//
//  Created by GitHub Copilot on 09/06/2025.
//

import Cocoa

class ClipboardTableRowView: NSTableRowView {

    private var trackingArea: NSTrackingArea?
    private var isMouseInside: Bool = false

    override func prepareForReuse() {
        super.prepareForReuse()
        isMouseInside = false
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isMouseInside = true
        needsDisplay = true // Redraw to show hover effect
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isMouseInside = false
        needsDisplay = true // Redraw to remove hover effect
    }

    override func drawBackground(in dirtyRect: NSRect) {
        // We handle all background drawing, so don't call super.
        if isMouseInside && !isSelected {
            AppColors.itemHoverBackground.setFill()
            let backgroundPath = NSBezierPath(rect: self.bounds)
            backgroundPath.fill()
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        if self.selectionHighlightStyle != .none {
            AppColors.itemSelectedBackground.setFill()
            let selectionRect = NSInsetRect(self.bounds, 0, 0) // Adjust inset if needed
            let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: 0, yRadius: 0) // No rounded corners for rows
            selectionPath.fill()
        }
    }

    override func drawSeparator(in dirtyRect: NSRect) {
        // Draw a custom bottom border
        let bottomBorderRect = NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
        AppColors.itemBorder.setFill()
        bottomBorderRect.fill()
    }
    
    // Make sure selection doesn't draw over the separator
    override var isOpaque: Bool {
        return false // Allows background of table view to show if row isn't drawing its own
    }
}
