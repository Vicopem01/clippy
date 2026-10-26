import XCTest
@testable import Clippy

final class ClippyTests: XCTestCase {

    func testTextClipboardItemEquality() {
        let item1 = ClipboardItem(text: "Hello World")
        let item2 = ClipboardItem(text: "Hello World")
        let item3 = ClipboardItem(text: "Different")

        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
        XCTAssertEqual(item1.displayString, "Hello World")
    }

    func testImageClipboardItemDigestEquality() {
        let size = NSSize(width: 10, height: 10)
        let image1 = NSImage(size: size)
        image1.lockFocus()
        NSColor.red.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        image1.unlockFocus()

        let tiffData = image1.tiffRepresentation
        let image2 = NSImage(data: tiffData!)!

        let clip1 = ClipboardItem(image: image1, imageData: tiffData)
        let clip2 = ClipboardItem(image: image2, imageData: tiffData)

        XCTAssertEqual(clip1, clip2)
        XCTAssertEqual(clip1.displayString, "[Image]")
    }

    func testFileClipboardItemEquality() {
        let url1 = URL(fileURLWithPath: "/tmp/example.txt")
        let url2 = URL(fileURLWithPath: "/tmp/example.txt")
        let url3 = URL(fileURLWithPath: "/tmp/other.txt")

        XCTAssertEqual(ClipboardItem(fileURL: url1), ClipboardItem(fileURL: url2))
        XCTAssertNotEqual(ClipboardItem(fileURL: url1), ClipboardItem(fileURL: url3))
    }
}
