// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

extension StoredKey {
    public enum GenerationSentinelResult:String {
        case passed, failed, multipleKeys
    }
    
    internal static func generationSentinel(
        _ basis:StoredKeyBasis, _ alias:String
    ) throws -> GenerationSentinelResult
    {
        let keys = try self.keysWithName(alias)
        if keys.count == 1 {
            let storedKey = basis.storedKey()
            let sentinel = "InMemorySentinel"
            let enciphered = try storedKey.encipher(sentinel)
            let deciphered = try self.decipher(
                enciphered, withFirstKeyNamed: alias)
            return sentinel == deciphered ? .passed : .failed
        }
        else {
            return .multipleKeys
        }
    }
    
    struct KeyGeneration:Encodable {
        let deletedFirst:Bool
        let sentinelCheck:String
        let summary:[String]
        let attributes:[String:AnyEncodable]
    }
}
