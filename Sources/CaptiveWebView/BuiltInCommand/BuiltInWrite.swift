// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

private enum KEY: String {
    // Common keys.
    case parameters
    
    // Keys used by `write` command.
    case base64decode, text, filename, wrote
}

// Convenience extension to facilitate use of the KEY enumeration as keys in a
// dictionary. TOTH for the setter:
// https://www.avanderlee.com/swift/custom-subscripts/#making-a-read-and-write-subscript
private extension Dictionary where Key == String {
    subscript(_ key:KEY) -> Value? {
        get { self[key.rawValue] }
        set { self[key.rawValue] = newValue }
    }
    
    @discardableResult mutating func removeValue(
        forKey key: KEY
    ) -> Value?
    {
        return removeValue(forKey: key.rawValue)
    }

}

extension CaptiveWebView.BuiltInCommand {
    public static func builtInWrite(
        _ commandDictionary: Dictionary<String, Any>
    ) throws -> Dictionary<String, Any>
    {
        let parameters = commandDictionary[.parameters]
            as? Dictionary<String, Any> ?? [:]
        
        // Get the parameters.
        guard let text = parameters[.text] as? String else {
            throw CaptiveWebViewError(
                "No text in parameters for write command: \(parameters)")
        }
        guard let filename = parameters[.filename] as? String else {
            throw CaptiveWebViewError(
                "No filename in parameters for write command: \(parameters)")
        }
        let asciiToBinary = parameters[.base64decode] as? Bool ?? false

        // Get the Documents/ directory for the app, and append the
        // specified file name.
        // If the app declares UISupportsDocumentBrowser:YES in its
        // Info.plist file then the files written here will be accessible
        // to, for example, the Files app on the device.
        let fileURL = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
            .appendingPathComponent(filename)

        // Write the file.
        if asciiToBinary {
            let data = Data(base64Encoded: text)
            try data?.write(to: fileURL)
        }
        else {
            try text.write(to:fileURL, atomically: true, encoding: .utf8)
        }

        // Generate a relative path that should be meaningful to the user.
        let root = URL.init(fileURLWithPath: NSHomeDirectory())
            .absoluteString
        let absolutePath = fileURL.absoluteString
        let relativePath = absolutePath.hasPrefix(root)
            ? String(fileURL.absoluteString.suffix(
                        absolutePath.count - root.count))
            : absolutePath
            
        return [KEY.wrote.rawValue: relativePath]
    }
}
