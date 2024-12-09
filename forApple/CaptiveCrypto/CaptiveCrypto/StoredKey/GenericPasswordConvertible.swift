// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import CryptoKit

// General approach to storing symmetric keys in the keychain, and code
// snippets, are from here:
// https://developer.apple.com/documentation/cryptokit/storing_cryptokit_keys_in_the_keychain

// Declare protocol.
protocol GenericPasswordConvertible: CustomStringConvertible {
    /// Creates a key from a raw representation.
    init<D>(rawRepresentation data: D) throws where D: ContiguousBytes
    
    /// A raw representation of the key.
    var rawRepresentation: Data { get }
}

// Add extension that makes CryptoKey SymmetricKey satisfy the protocol.
extension SymmetricKey: GenericPasswordConvertible {
    public var description: String {
        return "symmetrically"
    }
    
    init<D>(rawRepresentation data: D) throws where D: ContiguousBytes {
        self.init(data: data)
    }
    
    var rawRepresentation: Data {
        return withUnsafeBytes{Data($0)}
    }
}
// End of first code to support storing CryptoKit symmetric key in the keychain.
