// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

// Swift seems to have made it rather difficult to create a throw-able that
// has a message that can be retrieved in the catch. So, Captive Web View
// has its own custom class here.
//
// Having created a custom class anyway, it seemed like a code-saver to pack
// it with convenience initialisers for an array of strings, variadic
// strings, and CFString.

public class CaptiveWebViewError: Error {
    let message:String
    
    public init(_ message:String) {
        self.message = message
    }
    public convenience init(_ message:[String]) {
        self.init(message.joined())
    }
    public convenience init(_ message:String...) {
        self.init(message)
    }
    public convenience init(_ message:CFString) {
        self.init(NSString(string: message) as String)
    }
    
    var localizedDescription: String { self.message }
    
    var description: String { self.message }
}
