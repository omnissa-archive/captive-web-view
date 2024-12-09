// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause
import Foundation


extension StoredKey {
    // Enumeration for descriptive names for types of key pair.
    //
    // The values for the key type attribute, kSecAttrKeyType, have slightly
    // strange behaviour.
    //
    // In the dictionary passed to SecKeyCreateRandomKey, the value of the
    // kSecAttrKeyType attribute is a CFString. However, the contents of the
    // CFString will be numeric. For example, kSecAttrKeyTypeRSA has the
    // value "42". See, for example:
    // https://opensource.apple.com/source/Security/Security-55471/sec/Security/SecItemConstants.c.auto.html
    //
    // In the dictionary returned from SecItemCopyMatching, the value of the
    // kSecAttrKeyType attribute will be a CFNumber instead.
    //
    internal enum KeyType: String, CaseIterable {
        case RSA, EC

        var secAttrKeyType:CFString {
            switch self {
            case .RSA:
                return kSecAttrKeyTypeRSA
            case .EC:
                return kSecAttrKeyTypeECSECPrimeRandom
            }
        }
        // There is also a kSecAttrKeyTypeEC, which is deprecated. It has the
        // same value as kSecAttrKeyTypeECSECPrimeRandom. This means that
        // there's no way to tell the difference by matching.

        static func matching(_ secAttrKeyTypeValue:CFString) -> KeyType? {
            // self.allCases on the next line is enabled by CaseIterable in the
            // declaration.
            self.allCases.first(where: {
                $0.secAttrKeyType == secAttrKeyTypeValue
            })
        }

        // Nested struct for a description tuple containing:
        //
        // -   String, like "RSA" or "EC".
        // -   Raw value from a keychain query, or keychain attribute
        //     dictionary.
        //
        // In practice, the raw value will be CFNumber or CFString.
        struct Description:Encodable {
            let keyType:String
            let raw:AnyEncodable

            private init(keyType:String, raw:Encodable) {
                self.keyType = keyType
                self.raw = AnyEncodable(raw)
            }
            
            init(fromCopyAttribute specifier: Any) {
                // If the specifier is a number, compare numerically to the
                // numbers in each kSecAttrKeyType constant.
                if let typeNumber = specifier as? NSNumber,
                   let typeInt = Int(exactly: typeNumber),
                   let keyType = KeyType.allCases.first(where: {
                    Int($0.secAttrKeyType as String) == typeInt
                   })
                {
                    self.init(keyType: keyType.rawValue, raw: typeNumber)
                }
                // Otherwise, compare as a string.
                else if let typeString = specifier as? String {
                    self.init(
                        keyType:
                            KeyType.matching(typeString as CFString)?.rawValue
                            ?? typeString,
                        raw: typeString
                    )
                }
                // Otherwise, go through a catch-all.
                else {
                    self.init(keyType: "Unknown", raw: "\(specifier)")
                }
            }
        }
    }
}
