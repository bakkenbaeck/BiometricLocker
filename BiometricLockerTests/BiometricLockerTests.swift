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
        // Put setup code here. This method is called before the invocation of each test method in the class.
        self.locker.unlock()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
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

//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
}
