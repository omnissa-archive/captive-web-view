// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

extension StoredKey {
    // Encodable representation of a key, as returned by a keychain query.
    public struct Description:Encodable {
        let storage:String
        let name:String
        let type:String
        let attributes:[String:AnyEncodable]
        
        init(_ storage:Storage, _ attributes:NSDictionary) {
            self.storage = storage.rawValue
            
            // Create a dictionary of normalised values. Some of the normalised
            // values are also used in the rest of the constructor.
            self.attributes = Description.normalise(nsAttributes: attributes)
            
            // `name` will be the kSecAttrLabel if it can be a String, or the
            // empty string otherwise.
            self.name = attributes[kSecAttrLabel as String] as? String ?? ""

            // `type` will be a string derived by the KeyType.Description
            // constructor.
            let keyType:String
            if let element = self.attributes[kSecAttrKeyType as String] {
                if let description = element.encodable as? KeyType.Description {
                    keyType = description.keyType
                }
                else {
                    // Code reaches this point if there is somehow a value in
                    // the normalised dictionary that isn't a
                    // KeyType.Description, which shouldn't happen but just in
                    // case.
                    keyType = "\(element.encodable)"
                }
            }
            else {
                keyType = ""
            }
            self.type = keyType
        }

        static private func fallbackValue(_ rawValue:Any) -> Encodable {
            return rawValue as? NSNumber
                ?? (rawValue as? Encodable ?? "\(rawValue)")
        }
        
        static func normalise(
            nsAttributes:NSDictionary) -> [String:AnyEncodable]
        {
            // Keys in the attribute dictionary will sometimes be the short
            // names that are the underlying values of the various kSecAttr
            // constants. You can see a list of all the short names and
            // corresponding kSecAttr names in the Apple Open Source
            // SecItemConstants.c file. For example, here:
            // https://opensource.apple.com/source/Security/Security-55471/sec/Security/SecItemConstants.c.auto.html
            
            var returning: [String:AnyEncodable] = [:]
            for (rawKey, rawValue) in nsAttributes  {
                let value:Encodable
                    
                if let key = rawKey as? String {
                    // Check for known attributes with special handling first.
                    if key == kSecAttrApplicationTag as String {
                        if let rawData = rawValue as? Data {
                            value = String(data: rawData, encoding: .utf8)
                        }
                        else {
                            // If rawValue is a String already, or any other
                            // Encodable, the fallbackValue will return it.
                            value = fallbackValue(rawValue)
                        }
                    }
                    else if key == kSecAttrKeyType as String {
                        value = KeyType.Description(fromCopyAttribute: rawValue)
                    }
                    //
                    // Key isn't a known value with special handling.
                    else if let nsDictionary = rawValue as? NSDictionary {
                        // Recursive call to preserve hierarchy, for example if
                        // this is an attribute dictionary for a key pair.
                        value = normalise(nsAttributes: nsDictionary)
                    }
                    else {
                        value = fallbackValue(rawValue)
                    }
                    returning[key] = AnyEncodable(value)
                }
                else {
                    // Code reaches this point if the key couldn't be cast to
                    // String. This is a catch all.
                    returning[String(describing: rawKey)] =
                        AnyEncodable(fallbackValue(rawValue))
                }
            }
            return returning
        }
        
    }

    static func describeAll() throws -> [Description] {
        return try Storage.allCases.flatMap {storage -> [Description] in
            let query: [CFString: Any] = [
                kSecClass: storage.secClass,
                kSecReturnAttributes: true,
                kSecMatchLimit: kSecMatchLimitAll
            ]
            // Above query sets kSecMatchLimit: kSecMatchLimitAll so that the
            // results will be a CFArray. The type of each item in the array is
            // determined by which kSecReturn option is set.
            //
            // kSecReturnAttributes true
            // Gets a CFDictionary representation of each key.
            //
            // kSecReturnRef true
            // Would get a SecKey object for each key. A dictionary
            // representation can be generated from a SecKey by calling
            // SecKeyCopyAttributes(). However the resulting dictionary has only
            // a subset of the attributes. For example, it doesn't have these:
            //
            // -   kSecAttrLabel
            // -   kSecAttrApplicationTag
            //
            // kSecReturnData true
            // Gets a CFData instance for each key. From the reference documentation
            // it looks like the data should be a PKCS#1 representation.
            
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            // If SecItemCopyMatching failed, status will be a numeric error
            // code. To find out what a particular number means, you can look it
            // up here:
            // https://www.osstatus.com/search/results?platform=all&framework=all&search=errSec
            // That will get you the symbolic name.
            //
            // Symbolic names can be looked up in the official reference, here:
            // https://developer.apple.com/documentation/security/1542001-security_framework_result_codes
            // But it isn't searchable by number.
            //
            // This is how Jim found out that -25300 is errSecItemNotFound.
            
            // Set items to an NSArray of the return value, or an empty NSArray
            // in case of errSecItemNotFound.
            let items:NSArray
            if status == errSecSuccess {
                guard let nsArray = result as? NSArray else {
                    throw StoredKeyError(
                        "Couldn't cast result \(String(describing: result)) to",
                        " NSArray. Result was returned by",
                        "SecItemCopyMatching(\(query),)."
                    )
                }
                items = nsArray
            }
            else if status == errSecItemNotFound { items = NSArray() }
            else { throw StoredKeyError(
                status, " Returned by SecItemCopyMatching(\(query),).") }

            return try items.map { item -> Description in
                guard let nsDictionary = item as? NSDictionary else {
                    throw StoredKeyError(
                        "Couldn't cast item \(String(describing: item)) to",
                        " NSDictionary. Item was returned by",
                        "SecItemCopyMatching(\(query),)."
                    )
                }
                return Description(storage, nsDictionary)
            }
        }
    }
}
