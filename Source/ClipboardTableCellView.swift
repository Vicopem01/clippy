//
//  ClipboardTableCellView.swift
//  clipboard-swift
//
//  Created by GitHub Copilot on 09/06/2025.
//

import Cocoa

class ClipboardTableCellView: NSTableCellView {

    var itemImageView: NSImageView!
    var itemTextField: NSTextField!
    var dragHandleLabel: NSTextField!
    private var imageConstraints: [NSLayoutConstraint] = []
    private var textOnlyConstraints: [NSLayoutConstraint] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        // Create and configure the image view
        itemImageView = NSImageView()
        itemImageView.translatesAutoresizingMaskIntoConstraints = false
        itemImageView.imageScaling = .scaleProportionallyDown // Or another appropriate scaling
        addSubview(itemImageView)

        // Create and configure the text field
        itemTextField = NSTextField(labelWithString: "") // Initialize with empty string
        itemTextField.translatesAutoresizingMaskIntoConstraints = false
        itemTextField.isEditable = false
        itemTextField.isBordered = false
        itemTextField.backgroundColor = .clear
        itemTextField.font = NSFont.systemFont(ofSize: 11)
        itemTextField.textColor = AppColors.primaryText
        itemTextField.lineBreakMode = .byTruncatingTail
        itemTextField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        itemTextField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(itemTextField)

        // Create and configure the drag handle label
        dragHandleLabel = NSTextField(labelWithString: "⠿")
        dragHandleLabel.translatesAutoresizingMaskIntoConstraints = false
        dragHandleLabel.isEditable = false
        dragHandleLabel.isBordered = false
        dragHandleLabel.backgroundColor = .clear
        dragHandleLabel.font = NSFont.systemFont(ofSize: 12)
        dragHandleLabel.textColor = AppColors.dragHandle
        addSubview(dragHandleLabel)

        // Define constraints for image layout
        imageConstraints = [
            itemImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            itemImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            itemImageView.widthAnchor.constraint(equalToConstant: 30),
            itemImageView.heightAnchor.constraint(equalToConstant: 30),

            itemTextField.leadingAnchor.constraint(equalTo: itemImageView.trailingAnchor, constant: 8),
            itemTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            itemTextField.centerYAnchor.constraint(equalTo: centerYAnchor),
            itemTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 16)
        ]

        // Define constraints for text-only layout
        textOnlyConstraints = [
            itemTextField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            itemTextField.trailingAnchor.constraint(equalTo: dragHandleLabel.leadingAnchor, constant: -8),
            itemTextField.centerYAnchor.constraint(equalTo: centerYAnchor),
            itemTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 16),

            dragHandleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            dragHandleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ]
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Reset the views for reuse if necessary
        itemImageView.image = nil
        itemTextField.stringValue = ""
        dragHandleLabel.isHidden = true
        NSLayoutConstraint.deactivate(imageConstraints)
        NSLayoutConstraint.deactivate(textOnlyConstraints)
    }

    func configure(with item: ClipboardItem) { // Changed ClipboardHistoryViewController.ClipboardItem to ClipboardItem
        switch item.type {
        case .text(let text):
            if let firstLine = text.components(separatedBy: .newlines).first, text.contains("\n") {
                itemTextField.stringValue = "\(firstLine)..."
            } else {
                itemTextField.stringValue = text
            }
            itemImageView.image = nil
            itemImageView.isHidden = true
            dragHandleLabel.isHidden = false
            
            NSLayoutConstraint.deactivate(imageConstraints)
            NSLayoutConstraint.activate(textOnlyConstraints)

        case .image(let image):
            itemTextField.stringValue = "[Image]" // Placeholder text for images
            itemImageView.image = image
            itemImageView.isHidden = false
            dragHandleLabel.isHidden = true
            
            NSLayoutConstraint.deactivate(textOnlyConstraints)
            NSLayoutConstraint.activate(imageConstraints)
        }
    }
}
