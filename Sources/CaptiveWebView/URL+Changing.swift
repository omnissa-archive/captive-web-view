// Copyright 2023 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

public extension URL {
    func changing(lastPathComponent:String) -> URL {
        return deletingLastPathComponent().appendingPathComponent(
            lastPathComponent)
    }
    
    func changing(scheme:String) -> URL {
        var changed:URLComponents = URLComponents(
            url: self, resolvingAgainstBaseURL: false)!
        changed.scheme = scheme
        return changed.url!
    }
    
    func appending(pathComponents:[String]?) -> URL {
        var appended = self
        pathComponents?.forEach() {
            appended.appendPathComponent($0)
        }
        return appended
    }

    func appending(pathComponents:URL?) -> URL {
        // Extract the array of path components from the URL.
        // It's OK to pass nil.
        return self.appending(pathComponents: pathComponents?.pathComponents)
    }
}
