// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

extension Array {
    func inserting(_ element:Element, at index:Int) -> Array<Element> {
        var inserted = self
        inserted.insert(element, at: index)
        return inserted
    }
}
