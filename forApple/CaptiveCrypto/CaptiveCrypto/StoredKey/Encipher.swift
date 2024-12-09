// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import CryptoKit

extension StoredKey {
    
    // Tuple for enciphered data and the algorithm. The algorithm is for
    // description only. It is nil in the symmetric key case.
    public struct Enciphered {
        let message:Data
        let algorithm:SecKeyAlgorithm?
    }


    // Instance methods.
    func encipher(_ message:String) throws -> Enciphered
    {
        switch _storage {
        case .key:
            return try encipherBasedOnPrivateKey(message)
        case .generic:
            return try encipherWithSymmetricKey(message)
        }
    }

    private func encipherWithSymmetricKey(
        _ message:String) throws -> Enciphered
    {
        guard let key = symmetricKey else { throw StoredKeyError(
            "StoredKey instance isn't a symmetric key.")
        }
        guard let box = try
            AES.GCM.seal(Data(message.utf8) as NSData, using: key).combined else
        {
            throw StoredKeyError("Combined nil.")
        }
        return Enciphered(message:box, algorithm: nil)
    }

    // List of algorithms for public key encipherment.
    static internal let algorithms:[SecKeyAlgorithm] = [
        .eciesEncryptionStandardX963SHA1AESGCM,
        .rsaEncryptionOAEPSHA512
    ]

    private func encipherBasedOnPrivateKey(
        _ message:String) throws -> Enciphered
    {
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
        guard let encipheredBytes = SecKeyCreateEncryptedData(
            publicKey, algorithm, Data(message.utf8) as CFData, &error) else {
            throw error?.takeRetainedValue() as? Error ?? StoredKeyError(
                "SecKeyCreateEncryptedData(\(publicKey),",
                " \(algorithm), \(message),)",
                " returned null and set error \(String(describing: error)).")
        }
        return Enciphered(message: encipheredBytes as Data, algorithm:algorithm)
    }
    
    // Static method that work with a key alias instead of a StoredKey
    // instance.
    static func encipher(_ message:String, withFirstKeyNamed alias:String)
    throws -> Enciphered
    {
        guard let key = try keysWithName(alias).first else {
            throw StoredKeyError(errSecItemNotFound)
        }
        return try key.encipher(message)
    }
    
}
