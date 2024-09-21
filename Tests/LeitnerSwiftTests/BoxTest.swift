//
//  BoxTest.swift
//  
//
//  Created by Fatih Sağlam on 21.09.2024.
//

import XCTest
@testable import LeitnerSwift

class BoxTest: XCTestCase {
    func test_nextReviewDate_shouldBeTodayWhenCreated() {
        let sut = makeSUT(reviewInterval: 1)
        XCTAssertTrue(Calendar.current.isDateInToday(sut.nextReviewDate))
    }
    
    func test_nextReviewDate() {
        let intervals: [Double] = [1, 2, 3, 10, 30, 100, -1]
        intervals.forEach { interval in
            let sut = makeSUT(reviewInterval: interval, lastReviewedDate: fixedDate)
            let expectedNextReviewDate = Calendar.current.date(byAdding: .day, value: Int(interval), to: fixedDate)
            XCTAssertEqual(sut.nextReviewDate, expectedNextReviewDate)
        }
    }
    
    private var fixedDate: Date {
        return Date(timeIntervalSince1970: 0)  // Fixed date for testing
    }
    
    private func makeSUT(reviewInterval: Double, lastReviewedDate: Date? = nil) -> Box {
        Box(cards: [], reviewInterval: reviewInterval, lastReviewedDate: lastReviewedDate)
    }
}
