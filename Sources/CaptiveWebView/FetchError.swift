// Copyright 2023 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

class FetchError: Error {
    let message:String
    var details:[String: Any?] = [:]
    let cause:NSError?

    init(_ cause:NSError) {
        self.message = cause.domain
        self.cause = cause

        details[.message] = cause.localizedDescription
        cause.userInfo.forEach {key, value in
            
            
            // ToDo make a recursive extension to NSError that JSONifies it.
            
            
            details[key] = JSONSerialization.isValidJSONObject(value) ? value
            : String(describing: value)
        }
    }

    init(_ message:String) {
        self.message = message
        self.cause = nil
    }

    convenience init(_ message:String, _ details: [String : Any?]) {
        // The `details` parameter should be declared as this type.
        //
        //    details: [any RawRepresentable<String>: Any?]
        //
        // However, that syntax isn't supported prior to iOS 16.
        self.init(message)
        details.forEach() { self.details[$0] = $1 }
    }

    convenience init(_ message:String, _ details: [Key : Any?]) {
        self.init(message)
        details.forEach() { self.details[$0] = $1 }
    }

    convenience init(
        _ message:String,
        dictionary: [String:Any], missingKey:any RawRepresentable<String>
    ) {
        let typeString:String?
        let value: String?
        if let entry = dictionary[missingKey.rawValue] {
            typeString = String(describing: type(of: entry))
            value = String(describing: entry)
        }
        else {
            typeString = nil
            value = nil
        }
        
        self.init(message, [
            .keys: Array(dictionary.keys),
            .type: typeString,
            .value: value
        ] )
    }
    
    func appending(_ key: any RawRepresentable<String>, _ value: Any?)
    -> FetchError
    {
        details[key.rawValue] = value
        return self
    }
    
    func jsonAble(_ status: Int?) -> [String:Any?] {
        var return_:[String:Any?] = [:]
        return_[.ok] = false
        return_[.status] = status
        return_[.statusText] = message
        return_[.headers] = details
        return_[.text] = nil
        return_[.json] = nil
        return_[.peerCertificate] = nil
        return return_
    }

    
    enum Key: String {
        case ok, status, statusText, headers, text, json, peerCertificate
        case message
        case keys, type, value
    }
}


// Convenience extension to facilitate use of the KEY enumeration as keys in a
// dictionary. TOTH for the setter:
// https://www.avanderlee.com/swift/custom-subscripts/#making-a-read-and-write-subscript
private extension Dictionary where Key == String {
    subscript(_ key:FetchError.Key) -> Value? {
        get { self[key.rawValue] }
        set { self[key.rawValue] = newValue }
    }
}

// Clunky but can be used to create a dictionary with String keys from a
// dictionary literal with FetchError.Key keys.
private extension Dictionary where Key == FetchError.Key {
    func withStringKeys() -> [String: Value] {
        return Dictionary<String, Value>(uniqueKeysWithValues: self.map {
            ($0.rawValue, $1)
        })
    }
}
