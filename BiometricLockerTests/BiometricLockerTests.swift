//
//  BiometricLockerTests.swift
//  BiometricLockerTests
//
//  Created by Igor Ranieri on 16.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import XCTest
import LocalAuthentication
@testable import BiometricLocker

class BiometricLockerTests: XCTestCase {

    let locker = BiometricLocker()

    override func setUp() {
        super.setUp()
        self.locker.unlock()
        self.locker.unlockedTimeAllowance = LATouchIDAuthenticationMaximumAllowableReuseDuration
    }
    
    func testLockUnlock() {
        let expectation = self.expectation(description: "Locking")
        XCTAssertFalse(self.locker.isLocked)

        self.locker.unlockedTimeAllowance = 3
        self.locker.lock()
        XCTAssertFalse(self.locker.isLocked)

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            XCTAssertTrue(self.locker.isLocked)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 5)
    }

    func testLockUnlockImmediatelly() {
        XCTAssertFalse(self.locker.isLocked)

        self.locker.lock(.now)
        XCTAssertTrue(self.locker.isLocked)

        self.locker.unlock()
        XCTAssertFalse(self.locker.isLocked)
    }

    func testLockingAfterTimeAllowance() {
        XCTAssertFalse(self.locker.isLocked)
        let expectation = self.expectation(description: "Allowance time lock")

        self.locker.lock(.now)
        XCTAssertTrue(self.locker.isLocked)

        self.locker.unlock()
        XCTAssertFalse(self.locker.isLocked)

        self.locker.unlockedTimeAllowance = 5
        self.locker.lock(.afterTimeAllowance)
        XCTAssertFalse(self.locker.isLocked)

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            XCTAssertTrue(self.locker.isLocked)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 8)
    }

    func testLockingAfterCustomInterval() {
        XCTAssertFalse(self.locker.isLocked)
        let expectation = self.expectation(description: "Custom time lock")

        self.locker.lock(.now)
        XCTAssertTrue(self.locker.isLocked)

        self.locker.unlock()
        XCTAssertFalse(self.locker.isLocked)

        // We set the time allowance anyway, just to be sure that it's being ignored!
        self.locker.unlockedTimeAllowance = 3
        self.locker.lock(.afterTimeInterval(8))
        XCTAssertFalse(self.locker.isLocked)

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            XCTAssertFalse(self.locker.isLocked)

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                XCTAssertTrue(self.locker.isLocked)
                expectation.fulfill()
            }
        }

        self.wait(for: [expectation], timeout: 10)
    }
}
