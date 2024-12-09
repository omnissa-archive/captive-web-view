// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import CryptoKit

extension StoredKey {
     
    static func keysWithName(_ alias:String) throws -> [StoredKey] {
        return try Storage.allCases.flatMap {storage -> [StoredKey] in
            let query = [
                kSecClass: storage.secClass,
                kSecAttrLabel: alias,
                kSecMatchLimit: kSecMatchLimitAll,
                storage.kSecReturn: true
            ] as CFDictionary
            
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query, &result)

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
            
            return try items.map({item in
                switch(storage) {
                case .generic:
                    guard let data = item as? Data else { throw StoredKeyError(
                        "Couldn't initialise StoredKey SymmetricKey with name",
                        " \"\(alias)\".",
                        " Couldn't cast \(String(describing: item)) to Data.",
                        " Item was returned in SecItemCopyMatching(\(query),)",
                        " array."
                    ) }
                    return StoredKey(SymmetricKey(data: data))

                case .key: return StoredKey(item as! SecKey)
                // Jim couldn't find a way to do that other than as! cast.
                }
            })
        }
    }
    
}
