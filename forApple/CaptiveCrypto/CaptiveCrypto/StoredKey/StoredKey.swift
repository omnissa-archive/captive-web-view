// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import CryptoKit

class StoredKey {
    // Properties and methods of a StoredKey instance. It isn't necessary to use
    // StoredKey instances externally. The static methods, like
    // encypt(message withFirstKeyNamed:) for example, can be used instead.
    internal let _storage:Storage
    let secKey:SecKey?
    let symmetricKey:SymmetricKey?

    var storage:String {_storage.rawValue}

    // Symmetric key constructor.
    init(_ symmetricKey:SymmetricKey) {
        _storage = .generic
        secKey = nil
        self.symmetricKey = symmetricKey
    }
    
    // Key pair constructor. The SecKey will be the private key. The
    // corresponding public key will be generated as needed in either of the
    // encipher or decipher methods.
    init(_ secKey:SecKey) {
        _storage = .key
        self.secKey = secKey
        symmetricKey = nil
    }

}

protocol StoredKeyBasis {
    func storedKey() -> StoredKey
}
extension SecKey: StoredKeyBasis {
    func storedKey() -> StoredKey { return StoredKey(self) }
}
extension SymmetricKey: StoredKeyBasis {
    func storedKey() -> StoredKey { return StoredKey(self) }
}

