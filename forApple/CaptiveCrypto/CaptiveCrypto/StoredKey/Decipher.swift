// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import CryptoKit

extension StoredKey {
    // Instance methods.
    func decipher(_ enciphered:Data) throws -> String {
        switch _storage {
        case .key:
            return try decipherWithPrivateKey(enciphered as CFData)
        case .generic:
            return try decipherWithSymmetricKey(enciphered)
        }
    }
    func decipher(_ enciphered:Enciphered) throws -> String {
        return try decipher(enciphered.message)
    }
    
    private func decipherWithSymmetricKey(_ enciphered:Data) throws -> String {
        let sealed = try AES.GCM.SealedBox(combined: enciphered)
        guard let key = symmetricKey else { throw StoredKeyError(
            "StoredKey instance isn't a symmetric key.")
        }
        let decipheredData = try AES.GCM.open(sealed, using: key)
        let message =
            String(data: decipheredData, encoding: .utf8) ?? "\(decipheredData)"
        return message
    }

    private func decipherWithPrivateKey(_ enciphered:CFData) throws -> String {
        guard let privateKey = secKey else { throw StoredKeyError(
            "StoredKey instance isn't a key pair.")
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw StoredKeyError("No public key.")
        }
        guard let algorithm = StoredKey.algorithms.first(
            where: { SecKeyIsAlgorithmSupported(publicKey, .encrypt, $0)}
            ) else
        {
            throw StoredKeyError("No algorithms supported.")
        }

        var error: Unmanaged<CFError>?
        guard let decipheredBytes = SecKeyCreateDecryptedData(
            privateKey, algorithm, enciphered, &error) else {
            throw error?.takeRetainedValue() as? Error ?? StoredKeyError(
                "SecKeyCreateDecryptedData(\(privateKey),",
                " \(algorithm), \(enciphered),)",
                " returned null and set error \(String(describing: error)).")
        }
        
        let message = String(
            data: decipheredBytes as Data, encoding: .utf8)
            ?? "\(decipheredBytes)"
        return message
    }

    // Static methods that work with a key alias instead of a StoredKey
    // instance.
    static func decipher(
        _ enciphered:Enciphered, withFirstKeyNamed alias:String
    ) throws -> String
    {
        guard let key = try keysWithName(alias).first else {
            throw StoredKeyError(errSecItemNotFound)
        }
        return try key.decipher(enciphered)
    }
}
