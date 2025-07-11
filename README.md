# Clippy

A simple clipboard manager for macOS.

## Features

*   Stores your clipboard history.
*   Easy access to your clipboard history from the menu bar.
*   Search through your clipboard history.
*   Click to copy any item from your history back to your clipboard.
*   Global shortcut (Control + V) to open the clipboard history.

## Requirements

*   macOS 11.0 or later.
*   Xcode 13.0 or later.

## Installation

1.  Download the latest `Clippy.dmg` file from the [releases page](https://github.com/vicopem01/clippy/releases).
2.  Open the DMG file.
3.  Drag `Clippy.app` to your `Applications` folder.

## Permissions

Upon first launch, Clippy will request accessibility permissions. This is necessary for the global hotkey feature (Control + V) to work correctly. Please grant these permissions when prompted.

## Usage

1.  Launch Clippy.
2.  The Clippy icon will appear in your menu bar.
3.  Click the icon to see your clipboard history.
4.  Click any item to copy it back to your clipboard.

## Building from Source

1.  Clone the repository:
    ```bash
    git clone https://github.com/vicopem01/clippy.git
    ```
2.  Open the project in Xcode:
    ```bash
    open Clippy.xcodeproj
    ```
3.  Build and run the project.

Alternatively, you can use the provided build script:

```bash
./build.sh
```

This will create a `Clippy.dmg` file in the `build` directory.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
