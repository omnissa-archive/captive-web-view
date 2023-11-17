// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(CaptiveWebViewTests.allTests),
    ]
}
#endif
