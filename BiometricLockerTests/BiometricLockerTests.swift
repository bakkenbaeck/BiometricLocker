//
//  BiometricLockerTests.swift
//  BiometricLockerTests
//
//  Created by Igor Ranieri on 16.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

@testable import BiometricLocker
import LocalAuthentication
import XCTest

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

    func testLockUnlockImmediately() {
        let locker = BiometricLocker(localizedReason: "")
        XCTAssertFalse(locker.isLocked)

        locker.lock(.now)
        XCTAssertTrue(locker.isLocked)

        locker.unlock()
        XCTAssertFalse(locker.isLocked)
    }

    func testLockingAfterTimeAllowance() {
        let expectation = self.expectation(description: "Allowance time lock")

        let locker = BiometricLocker(localizedReason: "", withUnlockedTimeAllowance: 3)
        locker.lock(.afterTimeAllowance)
        XCTAssertFalse(locker.isLocked)

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            XCTAssertTrue(locker.isLocked)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 5)
    }

    func testLockingAfterCustomIntervalShorterThanTimeAllowance() {
        let locker = BiometricLocker(localizedReason: "", withUnlockedTimeAllowance: 3)
        XCTAssertFalse(locker.isLocked)
        let expectation = self.expectation(description: "Custom time lock shorter than time allowance")

        locker.lock(.afterTimeInterval(5))

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            // despite our time allowance being only 3, it should still be unlocked,
            // as we've defined a custom time interval when locking.
            XCTAssertFalse(locker.isLocked)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                // After a total of 6s, the locker should be locked, according to our custom time interval.
                XCTAssertTrue(locker.isLocked)

                expectation.fulfill()
            }
        }

        self.wait(for: [expectation], timeout: 7)
    }

    func testLockingAfterCustomInterval() {
        let expectation = self.expectation(description: "Custom time lock")

        // We set the time a specific allowance, just to be sure that it's being ignored!
        let locker = BiometricLocker(localizedReason: "", withUnlockedTimeAllowance: 3)
        XCTAssertFalse(locker.isLocked)
        locker.lock(.afterTimeInterval(8))
        XCTAssertFalse(locker.isLocked)

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            XCTAssertFalse(locker.isLocked)

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                XCTAssertTrue(locker.isLocked)
                expectation.fulfill()
            }
        }

        self.wait(for: [expectation], timeout: 10)
    }
}
