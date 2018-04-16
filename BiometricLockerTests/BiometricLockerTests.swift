//
//  BiometricLockerTests.swift
//  BiometricLockerTests
//
//  Created by Igor Ranieri on 16.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import XCTest
@testable import BiometricLocker

class BiometricLockerTests: XCTestCase {

    let locker = BiometricLocker()

    override func setUp() {
        super.setUp()
        self.locker.unlock()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testLockUnlock() {
        XCTAssertFalse(self.locker.isLocked)

        self.locker.lock()
        XCTAssertFalse(self.locker.isLocked)

        self.locker.lock(at: Date.distantPast)
        XCTAssertTrue(self.locker.isLocked)

        self.locker.unlock()
        XCTAssertFalse(self.locker.isLocked)
    }
}
