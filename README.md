# FileScrubby

## Overview
FileScrubby is a macOS application designed to help users manage and clean up their files efficiently. It provides a user-friendly interface for organizing, deleting, and maintaining files, ensuring a clutter-free workspace. This project leverages the Sparkle framework for seamless application updates, ensuring users always have access to the latest features and improvements.

## Key Features
- **File Management**: Easily organize and clean up files with an intuitive interface.
- **Sparkle Integration**: Automatic updates with secure digital signatures.
- **Customizable Menus**: Tailor the app to your workflow with flexible menu options.
- **macOS Native**: Built with Swift and optimized for macOS performance and design.

## Sparkle Updater
Sparkle is a popular open-source framework for macOS applications that provides an easy way to deliver updates to users. It ensures that users always have the latest version of the app with minimal effort.

### How Sparkle Works
1. **Appcast File**: The `appcast.xml` file in the `Releases/` directory contains metadata about available updates, including version numbers, release notes, and download links.
2. **Digital Signatures**: Sparkle uses digital signatures to verify the integrity and authenticity of updates. Ensure that each release is signed with the appropriate private key.
3. **Update Process**: When the app checks for updates, it reads the `appcast.xml` file, verifies the signature, and downloads the update if available.

## Steps for Each Release
Follow these steps to prepare and release a new version of FileScrubby:

1. **Update Version Information**:
   - Update the version number in `Info.plist` and any other relevant files.

2. **Build the Application**:
   - Open the `FileScrubby.xcodeproj` in Xcode.
   - Build the app in Release mode.

3. **Create a Disk Image (DMG)**:
   - Use a tool like `create-dmg` to package the app into a `.dmg` file.
   - Save the `.dmg` file in the `Releases/` directory.

4. **Generate Appcast Entry**:
   - Update the `appcast.xml` file in the `Releases/` directory with the new version details.
   - Include the version number, release notes, download URL, and signature.

5. **Sign the Update**:
   - Use the Sparkle signing tool to generate a signature for the `.dmg` file.
   - Add the signature to the `appcast.xml` entry.

6. **Test the Update**:
   - Run the app and check for updates to ensure the new version is detected and installed correctly.

7. **Publish the Release**:
   - Upload the updated `appcast.xml` and `.dmg` file to your server.
   - Ensure the URLs in `appcast.xml` point to the correct locations.

## Repository Structure
- `Scrubby/`: Contains the main application code, including Swift files and assets.
- `Releases/`: Stores the `appcast.xml` file and `.dmg` files for releases.
- `ScrubbyTests/` and `ScrubbyUITests/`: Contain unit and UI tests for the app to ensure quality and reliability.

## Getting Started
To get started with FileScrubby, follow these steps:

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/FileScrubby.git
   ```

2. Open the project in Xcode:
   ```bash
   open FileScrubby.xcodeproj
   ```

3. Build and run the app in Xcode.

## Contributing
Contributions are welcome! Please submit a pull request or open an issue for any bugs or feature requests. When contributing, ensure your code adheres to the project's coding standards and includes appropriate tests.

## License
This project is licensed under the MIT License. See the LICENSE file for details.