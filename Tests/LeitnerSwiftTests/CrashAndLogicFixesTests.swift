//
//  CrashAndLogicFixesTests.swift
//  LeitnerSwiftTests
//
//  Regression tests for ROADMAP step 2 (crashes and logic fixes).
//

import XCTest
@testable import LeitnerSwift

final class CrashAndLogicFixesTests: XCTestCase {

    // MARK: - B2: dueForReview(limit: negative) must not crash

    func test_dueForReview_withNegativeLimit_doesNotCrashAndReturnsNoCards() throws {
        let sut = LeitnerSystem(boxAmount: 3)
        sut.addCard(makeCard(with: UUID()))

        let result = try sut.dueForReview(limit: -1)

        XCTAssertTrue(result.isEmpty, "A negative limit should yield no cards instead of crashing.")
    }

    // MARK: - B3: empty boxes must not crash addCard/updateCard

    func test_addCard_afterLoadingEmptyBoxes_doesNotCrash() {
        let sut = LeitnerSystem(boxAmount: 3)
        sut.loadBoxes(boxes: [])

        sut.addCard(makeCard(with: UUID()))

        XCTAssertTrue(sut.allBoxes.isEmpty, "There are no boxes to add the card into, so nothing should happen.")
    }

    func test_updateCard_afterLoadingEmptyBoxes_throwsInsteadOfCrashing() {
        let sut = LeitnerSystem(boxAmount: 3)
        sut.loadBoxes(boxes: [])

        XCTAssertThrowsError(try sut.updateCard(makeCard(with: UUID()), correct: true)) { error in
            XCTAssertEqual(error as? LeitnerError, .cardNotFound)
        }
    }

    // MARK: - B4: retiring the last card in the last box must still update lastReviewedDate

    func test_updateCard_retiringLastCardInLastBox_updatesLastReviewedDate() throws {
        let sut = LeitnerSystem(boxAmount: 3)
        let card = makeCard(with: UUID())
        sut.addCard(card)
        try sut.updateCard(card, correct: true) // -> box 1
        try sut.updateCard(card, correct: true) // -> box 2 (last box)

        let previousDate = sut.allBoxes[2].lastReviewedDate

        try sut.updateCard(card, correct: true) // retires from last box

        XCTAssertTrue(sut.allBoxes[2].cards.isEmpty)
        XCTAssertNotEqual(sut.allBoxes[2].lastReviewedDate, previousDate, "The last box's lastReviewedDate must be refreshed even when the card retires, otherwise the box stays permanently due.")
    }

    // MARK: - B5: addCard must be idempotent for an id already in the system

    func test_addCard_withIdAlreadyInSystem_isNoOp() throws {
        let sut = LeitnerSystem(boxAmount: 3)
        let card = makeCard(with: UUID())
        sut.addCard(card)
        try sut.updateCard(card, correct: true) // card now lives in box 1

        sut.addCard(card) // attempt to add the same id again

        XCTAssertEqual(sut.cardCountsPerBox, [0, 1, 0], "The card must not exist in two boxes at once.")
    }

    // MARK: - B7: a large box amount must not overflow when extending intervals

    func test_init_withManyBoxes_doesNotOverflow() {
        let sut = LeitnerSystem(boxAmount: 70)

        XCTAssertEqual(sut.boxes.count, 70)
        for box in sut.boxes {
            XCTAssertLessThanOrEqual(box.reviewInterval, 365, "Extended intervals must be capped to avoid overflow.")
        }
    }

    func test_init_withSevenBoxes_keepsOriginalIntervals() {
        let sut = LeitnerSystem(boxAmount: 7)

        let expectedIntervals: [TimeInterval] = [0, 3, 7, 14, 30, 60, 120]
        for (index, box) in sut.boxes.enumerated() {
            XCTAssertEqual(box.reviewInterval, expectedIntervals[index], "B7's fix must not change the intervals up to 7 boxes.")
        }
    }

    // MARK: - Test Helpers

    private func makeCard(with id: UUID) -> Card {
        Card(id: id, word: Word(word: "word", languageCode: "en", meaning: "meaning", exampleSentence: nil))
    }
}
