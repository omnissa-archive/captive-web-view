// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import UIKit
import CaptiveWebView

import CryptoKit

// Convenience extension to facilitate use of the KEY enumeration as keys in a
// dictionary.
extension Dictionary where Key == String {
    subscript(_ key:MainViewController.KEY) -> Value? {
        get {
            return self[key.rawValue]
        }
    }

    // Following was intended as a way to use a dictionary literal in which the
    // keys are KEY as a dictionary with String keys. It doesn't work, although
    // it does compile.
//    init(dictionaryLiteral elements: (MainViewController.KEY, Value)...) {
//        let values = elements.map {
//            (key, value) in
//            return (key.rawValue, value)
//        }
//        self.init(uniqueKeysWithValues: values)
//    }
}

// Clunky but can be used to create a dictionary with String keys from a
// dictionary literal with KEY keys.
extension Dictionary where Key == MainViewController.KEY {
    func withStringKeys() -> [String: Value] {
        return Dictionary<String, Value>(uniqueKeysWithValues: self.map {
            ($0.rawValue, $1)
        })
    }
}

extension Dictionary where Key == CFString {
    func withStringKeys() -> [String: Value] {
        return Dictionary<String, Value>(uniqueKeysWithValues: self.map {
            ($0 as String, $1)
        })
    }
}

// Formatter for date representation like "28sep2020 16:53 BST".
class FancyDateFormatter {
    private static let formats = ["dd", "MMM", "yyyy HH:mm z"]
    private static let formatters: [DateFormatter] = { formats.map {
        let formatter = DateFormatter()
        formatter.dateFormat = $0
        return formatter
    } }()
    
    private init() {}
    
    static func string(from date:Date) -> String {
        return formatters
            .map{ $0.string(from: date) }
            .enumerated().map{
                $0.offset == 1 ? $0.element.lowercased() : $0.element
            }
            .joined()
    }
}

class MainViewController: CaptiveWebView.DefaultViewController {
    
    // Enumeration for commands from the JS layer.
    // Implicit raw values, see:
    // https://docs.swift.org/swift-book/LanguageGuide/Enumerations.html#ID535
    private enum Command: String {
        case capabilities, deleteAll, encipher, summariseStore,
             generateKey, generatePair
    }
    
    // Enumeration for dictionary keys to and from the JS layer.
    public enum KEY: String {
        case
            // Keys for capabilities command:
            secureEnclave, date,
            
            // Keys for encipher command, which is a test.
            parameters, alias, sentinel, results, failed, reason, count, storage,
            encipheredSentinel, algorithm, decipheredSentinel, passed, type
        
        // There are no extra keys for the summariseStore, generateKey, and
        // generateKeyPair commands. This is because their return values are
        // Encodable.
    }
    
    // Utility function to attempt to generate a generic object from an
    // Encodable, via the JSON encoder, and put it in a `results` mapping.
    private func result(of encodable:Encodable) throws -> [String: Any] {
        let encoder = JSONEncoder()
        let any:Any
        if let encoded = try? encoder.encode(AnyEncodable(encodable)) {
            any = try JSONSerialization.jsonObject(with: encoded, options: [])
        }
        else {
            any = encodable
        }

        return [KEY.results.rawValue: any]
    }
    
    override func response(
        to command: String,
        in commandDictionary: Dictionary<String, Any>
    ) throws -> [String: Any?]
    {
        do {
            switch Command(rawValue: command) {
                
            case .capabilities:
                return [
                    KEY.results: summariseCapabilities().withStringKeys()
                ].withStringKeys()
                
            case .deleteAll: return try result(of: StoredKey.deleteAll())
                
            case .encipher:
                guard let parameters = commandDictionary[KEY.parameters]
                        as? Dictionary<String, Any> else
                {
                    throw CaptiveWebViewError(
                        "Command `", Command.encipher.rawValue, "` requires `"
                        , KEY.parameters.rawValue, "`.")
                }
                guard let alias = parameters[KEY.alias] as? String else {
                    throw CaptiveWebViewError(
                        "Command `", Command.encipher.rawValue, "` requires `"
                        , KEY.parameters.rawValue, "` with `"
                        , KEY.alias.rawValue, "`.")
                }
                guard let sentinel = parameters[KEY.sentinel] as? String else {
                    throw CaptiveWebViewError(
                        "Command `", Command.encipher.rawValue, "` requires `"
                        , KEY.parameters.rawValue, "` with `",
                        KEY.sentinel.rawValue, "`.")
                }
                return try [
                    KEY.results: testKey(alias: alias, sentinel: sentinel)
                ].withStringKeys()
                
            case .summariseStore: return try result(of: StoredKey.describeAll())
                
            case .generateKey:
                guard
                    let parameters = commandDictionary[KEY.parameters]
                        as? Dictionary<String, Any>,
                    let alias = parameters[KEY.alias] as? String
                else {
                    throw CaptiveWebViewError(
                        "Key `", KEY.alias.rawValue,
                        "` must be specified in `", KEY.parameters.rawValue,
                        "`.")
                }
                
                return try result(of: StoredKey.generateKey(withName: alias))
                
            case .generatePair:
                guard
                    let parameters = commandDictionary[KEY.parameters]
                        as? Dictionary<String, Any>,
                    let alias = parameters[KEY.alias] as? String
                else {
                    throw CaptiveWebViewError(
                        "Key `", KEY.alias.rawValue,
                        "` must be specified in `", KEY.parameters.rawValue,
                        "`.")
                }
                return try result(
                    of: StoredKey.generateKeyPair(withName: alias))
                
            default:
                return try super.response(to: command, in: commandDictionary)
            }
        } catch let error as StoredKeyError {
            // Seems like the error has to be re-thrown with a specific type so
            // that the error message is available to the catcher.
            throw CaptiveWebViewError(error.localizedDescription)
        }
    }
    
    private func summariseCapabilities() -> [KEY:Any] {
        return [
            .secureEnclave: SecureEnclave.isAvailable,
            .date: FancyDateFormatter.string(from: Date())
        ]
    }
    
    private func testKey(alias: String, sentinel: String)
    throws -> [[String:Any]]
    {
        var results: [[String:Any]] = []

        let keys = try StoredKey.keysWithName(alias)
        guard keys.count == 1 else {
            if keys.count <= 0 {
                results.append([
                    KEY.failed.rawValue: [
                        KEY.reason: "No key found for alias", KEY.alias: alias
                    ].withStringKeys()
                ])
            }
            
            if keys.count > 1 {
                results.append([
                    KEY.failed.rawValue: [
                        KEY.reason: "Too many keys found for alias",
                        KEY.alias: alias,
                        KEY.count: keys.count
                    ].withStringKeys()
                ])
            }
            
            return results
        }

        results.append([
            KEY.type.rawValue: keys.first?.storage as Any,
            KEY.alias.rawValue: alias
        ])
        
        let enciphered:StoredKey.Enciphered
        do {
            enciphered = try StoredKey.encipher(
                sentinel, withFirstKeyNamed: alias)
            results.append([
                KEY.encipheredSentinel: String(describing: enciphered.message),
                KEY.algorithm: enciphered.algorithm?.rawValue as Any
            ].withStringKeys())
        }
        catch let error as StoredKeyError {
            results.append([KEY.failed.rawValue:error.localizedDescription])
            return results
        }
        catch {
            results.append([KEY.failed.rawValue:error.localizedDescription])
            return results
        }

        let deciphered:String
        do {
            deciphered = try StoredKey.decipher(
                enciphered, withFirstKeyNamed: alias)
            results.append([
                KEY.decipheredSentinel: deciphered,
                KEY.passed: deciphered == sentinel,
            ].withStringKeys())
        }
        catch let error as StoredKeyError {
            results.append([KEY.failed.rawValue:error.localizedDescription])
            return results
        }
        catch {
            results.append([KEY.failed.rawValue:error.localizedDescription])
            return results
        }

        return results
    }
}
