//
//  DueQueryAPITests.swift
//  LeitnerSwiftTests
//
//  Verifies that `dueCount` / `nextDueDate` reproduce, bit-for-bit, the
//  box-level due calculation the `wordlern` app currently keeps in
//  `WordViewModel` (see ROADMAP.md step 5). These tests must keep passing
//  unchanged after step 7 moves the underlying logic to card-level scheduling.
//

import Foundation
import XCTest
@testable import LeitnerSwift

final class DueQueryAPITests: XCTestCase {

    // MARK: - dueCount matches the app's own reduce-based calculation

    func test_dueCount_matchesAppsReferenceCalculation_forDemoContentSetup() throws {
        let sut = makeSUT()
        let intervals: [TimeInterval] = [0, 3, 7, 14, 30]
        let sessionBoxIndex = 1

        sut.loadBoxes(boxes: (0..<5).map { index in
            let interval = intervals[index]
            return makeBox(
                cards: [makeCard(), makeCard()],
                reviewInterval: interval,
                lastReviewedDate: index == sessionBoxIndex ? daysAgo(Int(interval) + 1) : daysAgo(0)
            )
        })

        XCTAssertEqual(sut.dueCount, referenceDueCount(for: sut.allBoxes, asOf: Date()))
        XCTAssertEqual(sut.dueCount, 4, "Session box (2 cards) + box 0 (2 cards) are due.")
    }

    func test_dueCount_matchesAppsReferenceCalculation_whenNothingIsDue() {
        let sut = makeSUT(boxAmount: 3)
        sut.loadBoxes(boxes: [
            makeBox(cards: [], reviewInterval: 0, lastReviewedDate: daysAgo(0)),
            makeBox(cards: [makeCard()], reviewInterval: 3, lastReviewedDate: daysAgo(1)),
            makeBox(cards: [makeCard()], reviewInterval: 7, lastReviewedDate: daysAgo(1)),
        ])

        XCTAssertEqual(sut.dueCount, referenceDueCount(for: sut.allBoxes, asOf: Date()))
        XCTAssertEqual(sut.dueCount, 0)
    }

    func test_dueCount_asOf_usesGivenDateInsteadOfNow() {
        let sut = makeSUT(boxAmount: 2)
        sut.loadBoxes(boxes: [
            makeBox(cards: [], reviewInterval: 0, lastReviewedDate: daysAgo(0)),
            makeBox(cards: [makeCard()], reviewInterval: 3, lastReviewedDate: daysAgo(0)),
        ])

        XCTAssertEqual(sut.dueCount(asOf: daysAgo(0)), 0, "Not due yet today.")
        XCTAssertEqual(sut.dueCount(asOf: Calendar.current.date(byAdding: .day, value: 3, to: Date())!), 1, "Due 3 days later.")
    }

    // MARK: - nextDueDate matches the app's own calculation

    func test_nextDueDate_isNil_whenCardsAreDue() {
        let sut = makeSUT()
        sut.addCard(makeCard())

        XCTAssertGreaterThan(sut.dueCount, 0)
        XCTAssertNil(sut.nextDueDate, "There is nothing to wait for when cards are already due.")
    }

    func test_nextDueDate_isEarliestNextReviewDate_acrossNonEmptyBoxes_whenNothingDue() {
        let sut = makeSUT(boxAmount: 3)
        sut.loadBoxes(boxes: [
            makeBox(cards: [], reviewInterval: 0, lastReviewedDate: daysAgo(0)),
            makeBox(cards: [makeCard()], reviewInterval: 3, lastReviewedDate: daysAgo(1)),
            makeBox(cards: [makeCard()], reviewInterval: 7, lastReviewedDate: daysAgo(1)),
        ])

        XCTAssertEqual(sut.dueCount, 0)
        XCTAssertEqual(
            sut.nextDueDate,
            referenceNextDueDate(for: sut.allBoxes),
            "Earliest nextReviewDate among boxes that still have cards."
        )
    }

    // MARK: - Test Helpers

    private func makeSUT(boxAmount: UInt? = nil) -> LeitnerSystem {
        boxAmount != nil ? LeitnerSystem(boxAmount: boxAmount!) : LeitnerSystem()
    }

    private func makeBox(
        cards: [Card] = [],
        reviewInterval: TimeInterval = 1,
        lastReviewedDate: Date? = Date()
    ) -> Box {
        .init(cards: cards, reviewInterval: reviewInterval, lastReviewedDate: lastReviewedDate)
    }

    private func makeCard(id: UUID = UUID()) -> Card {
        Card(
            id: id,
            word: Word(word: "defaultWord", languageCode: "en", meaning: "defaultMeaning", exampleSentence: nil)
        )
    }

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }

    /// Mirrors `WordViewModel.dueCount` in the `wordlern` app verbatim.
    private func referenceDueCount(for boxes: [Box], asOf date: Date) -> Int {
        let today = Calendar.current.startOfDay(for: date)
        return boxes.reduce(0) { result, box in
            box.cards.isEmpty ? result :
                (Calendar.current.startOfDay(for: box.nextReviewDate) <= today ? result + box.cards.count : result)
        }
    }

    /// Mirrors `WordViewModel.nextReviewDate` in the `wordlern` app verbatim.
    private func referenceNextDueDate(for boxes: [Box]) -> Date? {
        guard referenceDueCount(for: boxes, asOf: Date()) == 0 else { return nil }
        return boxes.filter { !$0.cards.isEmpty }.map(\.nextReviewDate).min()
    }
}
