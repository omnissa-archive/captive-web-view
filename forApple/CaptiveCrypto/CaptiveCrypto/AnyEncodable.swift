// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

// Dummy type to wrap any Encodable value.
struct AnyEncodable:Encodable {
    let encodable:Encodable
    
    init(_ encodable:Encodable) {
        self.encodable = encodable
    }

    func encode(to encoder: Encoder) throws {
        try encodable.encode(to: encoder)
    }
}
// This is here because the following doesn't compile:
//
//     public struct Description:Encodable {
//         let storage:String
//         let name:String
//         let type:String
//         let attributes:[String:Encodable] // This line is an error.
//     }
//
// It appears that there has to be an enum, struct or class wrapped around
// the object that is Encodable.
//


// Extensions to make some pre-Swift classes conform to Encodable.
extension NSNumber: Encodable {
    public func encode(to encoder: Encoder) throws {
        try Int(exactly: self).encode(to: encoder)
    }
}

extension CFNumber: Encodable {
    public func encode(to encoder: Encoder) throws {
        try (self as NSNumber).encode(to: encoder)
    }
}
extension CFString: Encodable {
    public func encode(to encoder: Encoder) throws {
        try (self as String).encode(to: encoder)
    }
}
