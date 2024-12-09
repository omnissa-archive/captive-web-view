// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

extension StoredKey {
    // Enumeration for different storage of keys supported by this class, either
    // as generic passwords in the keychain, or as keys in the keychain. The
    // keychain only stores private keys as keys, so symmetric keys must be
    // stored as generic passwords.
    internal enum Storage: String, CaseIterable {
        case generic, key

        var secClass:CFString { switch self {
        case .generic: return kSecClassGenericPassword
        case .key: return kSecClassKey
        } }
        
        var kSecReturn:CFString { switch self {
        case .generic: return kSecReturnData
        case .key: return kSecReturnRef
        } }
    }
}
