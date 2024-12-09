// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import CryptoKit

extension StoredKey {
    // Generate a symmetric key and store it in the keychain, as a generic
    // password.
    static func generateKey(withName alias:String) throws -> KeyGeneration {
        // First delete any generic key chain item with the same label. If you
        // don't, the add seems to fail as a duplicate.
        let deleteQuery:[CFString:Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrLabel: alias,
            
            // Generic passwords in the keychain use the following two items as
            // identifying attributes. If you don't set them, a first keychain
            // item will still be stored, but a second keychain item will be
            // rejected as a duplicate.
            // TOTH: https://useyourloaf.com/blog/keychain-duplicate-item-when-adding-password/
            kSecAttrAccount: "Account \(alias)",
            kSecAttrService: "Service \(alias)"
            
        ]
        let deleted = SecItemDelete(deleteQuery as CFDictionary)
        guard deleted == errSecSuccess || deleted == errSecItemNotFound else {
            throw StoredKeyError(
                deleted, "Failed SecItemDelete(\(deleteQuery)).")
        }

        // Generate the random symmetric key.
        let key = SymmetricKey(size: .bits256)
        
        // Merge in more query attributes, to create the add query.
        let addQuery = deleteQuery.merging([
            kSecReturnAttributes: true,
            kSecValueData: key.rawRepresentation,
        ]) {(_, new) in new}

        var result: CFTypeRef?
        let added = SecItemAdd(addQuery as CFDictionary, &result)
        guard added == errSecSuccess else {
            throw StoredKeyError(added, "Failed SecItemAdd(\(addQuery),)")
        }
        
        guard let nsDictionary = result as? NSDictionary else {
            throw StoredKeyError(
                "Couldn't cast result \(String(describing: result)) to",
                " NSDictionary. Result was returned by",
                "SecItemCopyMatching(\(addQuery),)."
            )
        }
        
        // The KeyGeneration here is a little different to the generateKeyPair
        // return value. That's because this key is created in memory and then
        // put in the keychain with a query, as two steps. Key pair generation
        // is already in the keychain as a single step.
        return KeyGeneration(
            deletedFirst: deleted == errSecSuccess,
            sentinelCheck: try generationSentinel(key, alias).rawValue,
            summary: [String(describing:key)],
            attributes: Description.normalise(nsAttributes: nsDictionary)
        )
    }
}
