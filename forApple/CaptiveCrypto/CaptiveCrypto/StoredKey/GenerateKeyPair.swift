// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

extension StoredKey {
    static func generateKeyPair(withName alias:String) throws -> KeyGeneration
    {
        // Official code snippets are here:
        // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/generating_new_cryptographic_keys
        
        let tagSD = try StoredKey.tag(forAlias: alias)
        let privateKeyAttributes:[CFString:Any] = [
            kSecAttrIsPermanent: true,
            kSecAttrLabel: alias,
            kSecAttrApplicationTag: tagSD.1
        ]
        let attributes = [
            // Next two lines are OK to create an RSA key.
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: 2048,
            
            // Next two lines would be OK to create an elliptic curve key.
            // kSecAttrKeySizeInBits: 256,
            // kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            
            // If you set an incompatible combination of bit size and type, you
            // get an OSstatus -50, which indicates that a parameter has an
            // invalid value.
            
            kSecPrivateKeyAttrs: privateKeyAttributes as CFDictionary
        ] as CFDictionary
        
        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateRandomKey(attributes, &error) else {
            throw error?.takeRetainedValue() as? Error ?? StoredKeyError(
                "SecKeyCreateRandomKey(\(attributes)",
                " returned null and set error \(String(describing: error)).")
        }

        // Make a copy of the attributes dictionary except with a String for the
        // tag, instead of data.
        let returning = NSMutableDictionary(dictionary: attributes)
        returning[kSecPrivateKeyAttrs] = privateKeyAttributes
            .merging([kSecAttrApplicationTag: tagSD.0]) {(_, new) in new}

        let summary = String(describing:secKey).split(separator: ",").map{
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // The String(describing:) in the above will return a value like this:
        //
        //     <SecKeyRef
        //         algorithm id: 1,
        //         key type: RSAPrivateKey,
        //         version: 4,
        //         block size: 2048 bits,
        //         addr: 0x280e3b560>
        //
        // (Split onto multiple lines here for readability.)
        //
        // That summary contains information that doesn't seem to be in the
        // attributes dictionary returned by:
        //
        //     SecKeyCopyAttributes(secKey)
        
        return KeyGeneration(
            deletedFirst: false,
            sentinelCheck: try generationSentinel(secKey, alias).rawValue,
            summary: summary,
            attributes: Description.normalise(nsAttributes: returning)
        )
    }
    
    private static func tag(forAlias alias: String) throws -> (String, Data) {
        let tagString = "com.example.keys.\(alias)"
        guard let tagData = tagString.data(using: String.Encoding.utf8) else {
            throw StoredKeyError(
                "Couldn't convert tag string \"\(tagString)\" to Data using",
                " utf8.")
        }
        return (tagString, tagData)
    }

}
