// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

extension StoredKey {
    
    
    struct Deletion: Encodable {
        let deleted: [String]
        let notDeleted: [String:String]
    }

    // Clears the keychain and returns a summary of what storage types were
    // deleted or not deleted because of an error.
    static func deleteAll() -> Deletion {
        var deleted:[String] = []
        var notDeleted:[String:String] = [:]
        
        for storage in Storage.allCases {
            // Query to find all items of this security class.
            let query: [CFString: Any] = [kSecClass: storage.secClass]
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound {
                deleted.append(storage.rawValue)
            }
            else {
                notDeleted[storage.rawValue] = status.secErrorMessage
            }
        }
        
        return Deletion(deleted: deleted, notDeleted: notDeleted)
    }
    
}
