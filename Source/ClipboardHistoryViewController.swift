//
//  ClipboardHistoryViewController.swift
//  clipboard-swift
//
//  Created by GitHub Copilot on 09/06/2025.
//

import Cocoa
import UniformTypeIdentifiers

struct ClipboardItem: Equatable {
    enum DataType: Equatable {
        case text(String)
        case image(NSImage) // Store NSImage directly
        case file(URL)

        // Equatable conformance for DataType
        static func == (lhs: DataType, rhs: DataType) -> Bool {
            switch (lhs, rhs) {
            case (.text(let lText), .text(let rText)):
                return lText == rText
            case (.image(let lImage), .image(let rImage)):
                // For simplicity, we can compare image data.
                // A more robust comparison might involve checking TIFF representations' equality
                // or even a visual hash if performance becomes an issue with many large images.
                return lImage.tiffRepresentation == rImage.tiffRepresentation
            case (.file(let lURL), .file(let rURL)):
                return lURL == rURL
            default:
                return false
            }
        }
    }

    let type: DataType
    let timestamp: Date // Keep track of when it was copied

    // Convenience initializer for text
    init(text: String) {
        self.type = .text(text)
        self.timestamp = Date()
    }

    // Convenience initializer for image
    init(image: NSImage) {
        self.type = .image(image)
        self.timestamp = Date()
    }
    
    // Convenience initializer for file URL
    init(fileURL: URL) {
        self.type = .file(fileURL)
        self.timestamp = Date()
    }

    // Equatable conformance for ClipboardItem
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        return lhs.type == rhs.type // Timestamps can differ for "same" content if re-copied
    }

    // Helper to get a display string, primarily for text or a placeholder for images
    var displayString: String {
        switch type {
        case .text(let text):
            return text
        case .image:
            return "[Image]" // Placeholder text for image items
        case .file(let url):
            let fileName = url.lastPathComponent
            if #available(macOS 11.0, *) {
                if let typeIdentifier = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
                   let utType = UTType(typeIdentifier) {
                    if utType.conforms(to: .image) {
                        return "🖼️ [Image] \(fileName)"
                    } else if utType.conforms(to: .movie) {
                        return "🎬 [Video] \(fileName)"
                    } else if utType.conforms(to: .audio) {
                        return "🎵 [Audio] \(fileName)"
                    } else if utType.conforms(to: .plainText) {
                        return "📄 [Text] \(fileName)"
                    }
                }
            }
            return "📁 [File] \(fileName)"
        }
    }

    // Helper to get the image if the item is an image
    var image: NSImage? {
        if case .image(let img) = type {
            return img
        }
        return nil
    }
}

class ClipboardHistoryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    private var pasteboard = NSPasteboard.general
    private var timer: Timer?
    // private var lastChangeCount: Int = 0 // Will be renamed and initialized in viewDidLoad
    private var lastPasteboardChangeCount: Int = 0 // Renamed and will be initialized
    // Store ClipboardItem structs instead of just Strings to support images later
    private var clipboardHistory: [ClipboardItem] = []
    private var isProgrammaticSelection: Bool = false // <-- This is the correct one
    private var emptyMessageLabel: NSTextField!
    private var headerView: NSView! // Declaration was already here
    private var clearHistoryButton: NSButton! // Added declaration
    private var headerBottomBorderLayer: CALayer? // Keep this for the header
    private var footerLabel: NSTextField! // <-- New footer label

    private let MAX_HISTORY_ITEMS = 10

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppColors.popoverBackground.cgColor
        self.preferredContentSize = NSSize(width: 260, height: 355)

        self.lastPasteboardChangeCount = NSPasteboard.general.changeCount // Initialize here

        setupHeaderView()
        setupScrollView() // This method already sets up the tableView
        // setupTableView() // Removed redundant call
        setupEmptyMessageLabel()
        setupFooterLabel() // <-- Call new setup method

        // Register for drag and drop
        tableView.registerForDraggedTypes([NSPasteboard.PasteboardType.string])
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false) // Allow dragging to other apps

        checkClipboard() // Changed from checkPasteboard() for consistency & initial check
        updateViewVisibility() // Changed from updateUIForHistoryState()
        startMonitoringClipboard() // <-- Add this line to start monitoring
        print("ClipboardHistoryViewController loaded with custom header, styled, and table view set up.")
    }

    private func setupHeaderView() {
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true // Essential for adding custom sublayers
        headerView.layer?.backgroundColor = AppColors.headerBackground.cgColor
        
        // Add bottom border to header
        let border = CALayer()
        // Initial frame, width will be updated in viewDidLayoutSubviews
        border.frame = CGRect(x: 0, y: 0, width: 0, height: 1) 
        border.backgroundColor = AppColors.itemBorder.cgColor
        headerView.layer?.addSublayer(border)
        self.headerBottomBorderLayer = border // Store reference

        // REMOVED problematic lines:
        // headerView.layer?.layoutManager = CAConstraintLayoutManager()
        // bottomBorder.addConstraint(CAConstraint(attribute: .width, relativeTo: "superlayer", attribute: .width))

        self.view.addSubview(headerView)

        // Title Label "CLIPBOARD HISTORY"
        let titleLabel = NSTextField(labelWithString: "CLIPBOARD HISTORY")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium) // From modal.css .modal-header
        titleLabel.textColor = AppColors.headerTitleText
        // Letter spacing from modal.css (0.5px)
        let attributedString = NSMutableAttributedString(string: titleLabel.stringValue)
        attributedString.addAttribute(.kern, value: 0.5, range: NSRange(location: 0, length: attributedString.length))
        titleLabel.attributedStringValue = attributedString
        headerView.addSubview(titleLabel)

        // Clear Button
        clearHistoryButton = NSButton()
        clearHistoryButton.translatesAutoresizingMaskIntoConstraints = false
        clearHistoryButton.title = "clear"
        clearHistoryButton.bezelStyle = .texturedSquare // Gives a button look, can be customized
        clearHistoryButton.isBordered = false // Remove system border
        clearHistoryButton.wantsLayer = true
        clearHistoryButton.layer?.backgroundColor = NSColor.clear.cgColor // Transparent background
        clearHistoryButton.layer?.cornerRadius = 3 // From modal.css .clear-button
        
        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = .center
        let clearButtonAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold), // From modal.css .clear-button
            .foregroundColor: AppColors.headerClearButtonText,
            .paragraphStyle: pStyle
        ]
        clearHistoryButton.attributedTitle = NSAttributedString(string: "clear", attributes: clearButtonAttributes)
        clearHistoryButton.target = self
        clearHistoryButton.action = #selector(clearHistoryClicked)
        // Add hover effect for clear button (visual only, actual color change might need tracking area or subclass)
        // For simplicity, we'll rely on system hover or a simpler visual cue if needed.
        // True CSS-like hover requires more work (e.g., NSTrackingArea on the button).
        headerView.addSubview(clearHistoryButton)

        // Constraints for Header View and its contents
        let headerHeight: CGFloat = 30 // Approximate height based on image and modal.css padding
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: self.view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: headerHeight),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12), // modal.css padding
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            clearHistoryButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12), // modal.css padding
            clearHistoryButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            clearHistoryButton.widthAnchor.constraint(equalToConstant: 40), // From modal.css .clear-button (approx)
            clearHistoryButton.heightAnchor.constraint(equalToConstant: 18) // From modal.css .clear-button
        ])
    }

    // Corrected lifecycle method for NSViewController
    override func viewDidLayout() { // Corrected method name
        super.viewDidLayout()
        // Update the header's bottom border frame width here
        // This is called after Auto Layout has determined headerView's bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true) // Avoid implicit animation
        self.headerBottomBorderLayer?.frame = CGRect(x: 0, y: 0, width: headerView.bounds.width, height: 1)
        CATransaction.commit()
    }

    @objc private func clearHistoryClicked() {
        clipboardHistory.removeAll()
        // TODO: Persist this change if history is saved
        DispatchQueue.main.async {
            self.updateViewVisibility() // Changed from updateUIForHistoryState()
            self.tableView.reloadData()
        }
        print("Clipboard history cleared.")
    }

    private func setupEmptyMessageLabel() {
        emptyMessageLabel = NSTextField(labelWithString: "No clipboard history yet")
        emptyMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyMessageLabel.isBezeled = false
        emptyMessageLabel.drawsBackground = false
        emptyMessageLabel.isEditable = false
        emptyMessageLabel.textColor = AppColors.emptyMessageText
        emptyMessageLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        emptyMessageLabel.alignment = .center
        emptyMessageLabel.isHidden = true // Initially hidden
        self.view.addSubview(emptyMessageLabel)

        NSLayoutConstraint.activate([
            emptyMessageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyMessageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: headerView.frame.height / 2), // Adjust vertical position
            // Bottom constraint will be handled by footer or superview
        ])
    }

    private func setupFooterLabel() {
        let madeWithText = "Made with ❤️ by "
        let authorText = "Victor"
        let fullText = "\(madeWithText)\(authorText)"
        let urlString = "https://github.com/Vicopem01"

        let attributedString = NSMutableAttributedString(string: fullText)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let fullRange = NSRange(location: 0, length: attributedString.length)

        // Base attributes
        attributedString.addAttributes([
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .paragraphStyle: paragraphStyle
        ], range: fullRange)

        // Color and link attributes
        let madeWithRange = (fullText as NSString).range(of: madeWithText)
        if let url = URL(string: urlString) {
            attributedString.addAttributes([
                .foregroundColor: AppColors.footerText,
                .link: url,
                .underlineStyle: 0 // No underline
            ], range: madeWithRange)
        }


        let authorRange = (fullText as NSString).range(of: authorText)
        attributedString.addAttribute(.foregroundColor, value: AppColors.authorLink, range: authorRange)

        // Add link to the author text and customize appearance
        if let url = URL(string: urlString) {
            attributedString.addAttributes([
                .link: url,
                .underlineStyle: 0 // No underline
            ], range: authorRange)
        }

        footerLabel = NSTextField(labelWithAttributedString: attributedString)
        footerLabel.isBordered = false
        footerLabel.isEditable = false
        footerLabel.isSelectable = false
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.allowsEditingTextAttributes = false
        footerLabel.drawsBackground = false

        view.addSubview(footerLabel)

        NSLayoutConstraint.activate([
            footerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            footerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            footerLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            footerLabel.heightAnchor.constraint(equalToConstant: 15)
        ])

        // Adjust scrollView bottom constraint
        if let existingBottomConstraint = scrollView.constraints.first(where: { $0.firstAttribute == .bottom && $0.secondAttribute == .bottom && $0.relation == .equal && $0.secondItem === view }) {
            existingBottomConstraint.isActive = false
        }
         scrollView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -5).isActive = true
    }


    private func updateViewVisibility() { // This is the correct method name
        tableView.reloadData()
        emptyMessageLabel.isHidden = !clipboardHistory.isEmpty
        tableView.isHidden = clipboardHistory.isEmpty
        scrollView.isHidden = clipboardHistory.isEmpty

        // Ensure footer is always visible if added
        footerLabel.isHidden = false
    }

    private func setupScrollView() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false // Ensure scroll view itself is transparent
        scrollView.scrollerStyle = .overlay // Use overlay scrollers for a modern look
        // Note: Customizing NSScroller colors (thumb/track) directly is complex.
        // AppColors.scrollBarThumb and AppColors.scrollBarTrack are defined but may require subclassing NSScroller.

        tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear // Table itself is clear, rows will draw their own backgrounds
        tableView.selectionHighlightStyle = .none // We handle selection drawing in ClipboardTableRowView
        tableView.gridStyleMask = [] // No grid lines
        tableView.intercellSpacing = NSSize(width: 0, height: 0) // No intercell spacing

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ClipboardItemColumn"))
        // column.title = "History" // Not needed as header is hidden
        column.width = 220 // Adjust as needed, considering scrollbar
        tableView.addTableColumn(column)

        // Register the custom cell view class if not using NIBs for cells
        // tableView.register(ClipboardTableCellView.self, forIdentifier: NSUserInterfaceItemIdentifier("ClipboardCell"))
        // No need to register if we are creating it manually in tableView(_:viewFor:row:)

        scrollView.documentView = tableView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // Constraint to footerLabel will be added in setupFooterLabel or adjusted if emptyMessageLabel is shown
        ])
        
        // To allow selection and keyboard navigation
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        // Stop the timer when the view is not visible to save resources
        // timer?.invalidate()
        // timer = nil 
        // Commenting out for now, as popover is transient and might close frequently.
        // We want to keep monitoring even if popover is not shown.
    }

    deinit {
        stopMonitoringClipboard()
    }

    func startMonitoringClipboard() {
        // Run a timer every 1 second (same as Electron app)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        // Add to runloop common to ensure it fires when UI is active (e.g. scrolling)
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
        print("Clipboard monitoring started.")
    }

    func stopMonitoringClipboard() {
        timer?.invalidate()
        timer = nil
        print("Clipboard monitoring stopped.")
    }

    @objc private func checkClipboard() {
        // Removed problematic guard:
        // guard let lastChangeCount = self.lastPasteboardChangeCount else {
        //     self.lastPasteboardChangeCount = NSPasteboard.general.changeCount
        //     return
        // }

        let currentSystemChangeCount = NSPasteboard.general.changeCount
        if currentSystemChangeCount == self.lastPasteboardChangeCount {
            return // No change detected
        }

        // If execution reaches here, the pasteboard has changed.
        // Update our record of the pasteboard's state to this new count.
        self.lastPasteboardChangeCount = currentSystemChangeCount
        
        var newItem: ClipboardItem?
        let pasteboard = NSPasteboard.general

        // Prioritize file URLs. This is a more robust way to detect file copies.
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !fileURLs.isEmpty {
            // For simplicity, we'll take the first file URL if multiple are copied.
            newItem = ClipboardItem(fileURL: fileURLs[0])
        } else if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            // Create a new NSImage instance from the pasteboard image's TIFF representation
            // This helps in detaching it from the pasteboard and ensuring it's a distinct copy.
            if let tiffData = image.tiffRepresentation, let copiedImage = NSImage(data: tiffData) {
                newItem = ClipboardItem(image: copiedImage)
            }
        } else if let text = NSPasteboard.general.string(forType: .string) {
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                newItem = ClipboardItem(text: text)
            }
        }


        if let item = newItem {
            // Remove if item already exists (based on content for text items or image data)
            // Use Equatable conformance of ClipboardItem
            if let existingIndex = clipboardHistory.firstIndex(of: item) {
                clipboardHistory.remove(at: existingIndex)
            }

            clipboardHistory.insert(item, at: 0)

            if clipboardHistory.count > MAX_HISTORY_ITEMS {
                clipboardHistory = Array(clipboardHistory.prefix(MAX_HISTORY_ITEMS))
            }

            print("Current history count: \\(clipboardHistory.count)")
            DispatchQueue.main.async {
                self.updateViewVisibility() // Changed from updateUIForHistoryState()
                self.tableView.reloadData()
                if !self.clipboardHistory.isEmpty {
                    self.isProgrammaticSelection = true // Set flag before programmatic selection
                    self.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                    self.tableView.scrollRowToVisible(0)
                    self.isProgrammaticSelection = false // Reset flag after selection
                }
            }
        }
    }

    // MARK: - NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return clipboardHistory.count
    }

    // To enable dragging from the table view
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        // We only support dragging single rows for now.
        guard rowIndexes.count == 1, let rowIndex = rowIndexes.first else {
            return false
        }

        guard rowIndex < clipboardHistory.count else {
            return false
        }

        let item = clipboardHistory[rowIndex]

        switch item.type {
        case .text(let text):
            pboard.clearContents()
            if pboard.setString(text, forType: .string) {
                print("Dragging text: \(text)")
                // Notify AppDelegate to close the popover
                NotificationCenter.default.post(name: NSNotification.Name("ClippyItemDidBeginDrag"), object: nil)
                return true
            }
            return false
        case .image:
            // Dragging images directly into input fields is not the primary request here.
            // For now, we only support dragging text.
            print("Dragging images is not currently supported via this method.")
            return false
        case .file:
            // Dragging files directly into input fields is not the primary request here.
            // For now, we only support dragging text.
            print("Dragging files is not currently supported via this method.")
            return false
        }
    }

    // MARK: - NSTableViewDelegate
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = ClipboardTableRowView()
        // Potentially pass data or configure rowView if needed, though most is handled by selection state
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < clipboardHistory.count else { return nil }
        let item = clipboardHistory[row]

        let cellIdentifier = NSUserInterfaceItemIdentifier("ClipboardCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? ClipboardTableCellView
        
        if cell == nil {
            cell = ClipboardTableCellView()
            cell?.identifier = cellIdentifier
        }

        // The configure method now handles all setup, including text truncation
        cell?.configure(with: item)
        
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if isProgrammaticSelection { // If selection was programmatic, do nothing further.
            return
        }

        guard tableView.selectedRow >= 0, tableView.selectedRow < clipboardHistory.count else { return }

        let selectedItem = clipboardHistory[tableView.selectedRow]

        NSPasteboard.general.clearContents()
        var success = false

        switch selectedItem.type {
        case .text(let text):
            success = NSPasteboard.general.setString(text, forType: .string)
        case .image(let image):
            // For images, we need to write the image object to the pasteboard.
            // NSImage conforms to NSPasteboardWriting, so it can be written directly.
            success = NSPasteboard.general.writeObjects([image])
        case .file(let url):
            success = NSPasteboard.general.setString(url.absoluteString, forType: .fileURL)
        }

        if success {
            print("Copied to clipboard: \(selectedItem.displayString)")
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.closePopover(sender: nil)
            }
        } else {
            print("Error copying to clipboard")
        }
        tableView.deselectRow(tableView.selectedRow) // Deselect after copy
    }

    // Set row height
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        // From modal.css .history-item padding: 8px 12px; font-size: 12px;
        // Assuming a 12px font, a 16px image. Total height could be 16 (image) + 2*8 (padding) = 32.
        // Or based on text line height + padding.
        // The Electron app seems to have items around 34-36px total height on screen.
        return 28 // Adjust for desired padding and content height
    }
}
