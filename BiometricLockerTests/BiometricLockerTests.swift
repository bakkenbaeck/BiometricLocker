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

    override func setUp() {
        super.setUp()

        // Since lockers are not namespaced or anything, if you have multiple lockers, they'll all use the same UserDefaults date value.
        // To ensure we're always starting from scratch, create one and unlock to clear the UserDefaults value. Will improve on this.
        BiometricLocker(localizedReason: "").unlock()
    }

    func testLockUnlock() {
        let expectation = self.expectation(description: "Locking")

        let locker = BiometricLocker(localizedReason: "", withUnlockedTimeAllowance: 3)
        XCTAssertFalse(locker.isLocked)

        locker.lock()
        XCTAssertFalse(locker.isLocked)

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            XCTAssertTrue(locker.isLocked)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 5)
    }

    func testLockUnlockImmediatelly() {
        let locker = BiometricLocker(localizedReason: "")
        XCTAssertFalse(locker.isLocked)

        locker.lock(.now)
        XCTAssertTrue(locker.isLocked)

        locker.unlock()
        XCTAssertFalse(locker.isLocked)
    }

    func testLockingAfterTimeAllowance() {
        let locker = BiometricLocker(localizedReason: "")
        XCTAssertFalse(locker.isLocked)
        let expectation = self.expectation(description: "Allowance time lock")

        locker.lock(.now)
        XCTAssertTrue(locker.isLocked)

        locker.unlock()
        XCTAssertFalse(locker.isLocked)

        let otherLocker = BiometricLocker(localizedReason: "", withUnlockedTimeAllowance: 3)
        otherLocker.lock(.afterTimeAllowance)
        XCTAssertFalse(otherLocker.isLocked)

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            XCTAssertTrue(otherLocker.isLocked)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 8)
    }

    func testLockingAfterCustomInterval() {
        let locker = BiometricLocker(localizedReason: "")
        XCTAssertFalse(locker.isLocked)
        let expectation = self.expectation(description: "Custom time lock")

        locker.lock(.now)
        XCTAssertTrue(locker.isLocked)

        locker.unlock()
        XCTAssertFalse(locker.isLocked)

        // We set the time a specific allowance, just to be sure that it's being ignored!
        let otherLocker = BiometricLocker(localizedReason: "", withUnlockedTimeAllowance: 3)
        otherLocker.lock(.afterTimeInterval(8))
        XCTAssertFalse(otherLocker.isLocked)

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            XCTAssertFalse(otherLocker.isLocked)

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                XCTAssertTrue(otherLocker.isLocked)
                expectation.fulfill()
            }
        }

        self.wait(for: [expectation], timeout: 10)
    }
}
