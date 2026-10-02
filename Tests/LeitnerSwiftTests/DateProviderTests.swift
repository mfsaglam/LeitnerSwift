//
//  DateProviderTests.swift
//  LeitnerSwiftTests
//

import Foundation
import XCTest
@testable import LeitnerSwift

final class DateProviderTests: XCTestCase {

    func test_defaultInit_isSourceCompatible_withoutDateProvider() {
        XCTAssertNoThrow(LeitnerSystem())
        XCTAssertNoThrow(LeitnerSystem(boxAmount: 5))
    }

    func test_cardMovedToNextBox_isNotDueImmediately_butBecomesDueAfterIntervalElapses() throws {
        var currentDate = Date()
        let sut = LeitnerSystem(boxAmount: 5, dateProvider: { currentDate })

        let card = Card(id: UUID(), word: makeWord())
        sut.addCard(card)

        // Correct answer moves the card from box 0 (interval 0) to box 1 (interval 3).
        try sut.updateCard(card, correct: true)

        // Box 1 was initialized with `currentDate` and has a 3-day interval,
        // so the card should not be due the same day it arrives.
        XCTAssertThrowsError(try sut.dueForReview())

        // Advance the injected clock by 3 days.
        currentDate = Calendar.current.date(byAdding: .day, value: 3, to: currentDate)!

        let dueCards = try sut.dueForReview()
        XCTAssertEqual(dueCards.map(\.id), [card.id])
    }

    private func makeWord() -> Word {
        Word(word: "hello", languageCode: "en", meaning: "merhaba", exampleSentence: "Hello there.")
    }
}
