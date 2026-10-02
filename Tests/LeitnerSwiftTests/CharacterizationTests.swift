//
//  CharacterizationTests.swift
//
//
//  Pins today's observable behaviour of the package so that the later steps of
//  the fix plan (see ROADMAP.md) can tell an intended change apart from a
//  regression. These tests describe the system as it is, not as it should be —
//  the box-level scheduling bug (B1) is deliberately *not* asserted here.
//

import Foundation
import XCTest
@testable import LeitnerSwift

class CharacterizationTests: XCTestCase {

    // MARK: - 1. A newly added card is due immediately

    func test_characterization_newlyAddedCard_isDueImmediately() throws {
        let sut = makeSUT()
        let card = makeCard()

        sut.addCard(card)

        let due = try sut.dueForReview()
        XCTAssertEqual(due.map(\.id), [card.id], "A card added today is due the same day, because box 0's interval is 0.")
    }

    // MARK: - 2. Box 0 has a zero interval, so it is always due

    func test_characterization_firstBox_hasZeroReviewInterval() {
        let sut = makeSUT()
        XCTAssertEqual(sut.allBoxes[0].reviewInterval, 0, "Box 0's interval is 0 by design: cards there are due every day.")
    }

    func test_characterization_incorrectlyAnsweredCard_isDueAgainTheSameDay() throws {
        let sut = makeSUT()
        let card = makeCard()
        sut.addCard(card)
        _ = try sut.dueForReview()

        try sut.updateCard(card, correct: false)

        let due = try sut.dueForReview()
        XCTAssertEqual(due.map(\.id), [card.id], "A wrong answer sends the card back to box 0, where it is due again right away.")
    }

    func test_characterization_cardDemotedFromHigherBox_isDueAgainTheSameDay() throws {
        let sut = makeSUT()
        let card = makeCard()
        sut.addCard(card)
        try moveCardForward(card: card, to: 3, in: sut)

        try sut.updateCard(card, correct: false)

        XCTAssertEqual(sut.cardCountsPerBox, [1, 0, 0, 0, 0])
        XCTAssertEqual(try sut.dueForReview().map(\.id), [card.id])
    }

    // MARK: - 3. `dueForReview` walks the boxes from last to first and applies `limit`

    func test_characterization_dueForReview_returnsHigherBoxesFirst() throws {
        let sut = makeSUT(boxAmount: 3)
        let (card0, card1, card2) = (makeCard(), makeCard(), makeCard())

        sut.loadBoxes(boxes: [
            makeBox(cards: [card0], reviewInterval: 0, lastReviewedDate: daysAgo(0)),
            makeBox(cards: [card1], reviewInterval: 3, lastReviewedDate: daysAgo(4)),
            makeBox(cards: [card2], reviewInterval: 7, lastReviewedDate: daysAgo(8)),
        ])

        let due = try sut.dueForReview(limit: 10)

        XCTAssertEqual(
            due.map(\.id),
            [card2.id, card1.id, card0.id],
            "Boxes are visited in reverse order, so the highest box's cards come first."
        )
    }

    func test_characterization_dueForReview_appliesLimitAfterOrdering() throws {
        let sut = makeSUT(boxAmount: 3)
        let (card0, card1, card2) = (makeCard(), makeCard(), makeCard())

        sut.loadBoxes(boxes: [
            makeBox(cards: [card0], reviewInterval: 0, lastReviewedDate: daysAgo(0)),
            makeBox(cards: [card1], reviewInterval: 3, lastReviewedDate: daysAgo(4)),
            makeBox(cards: [card2], reviewInterval: 7, lastReviewedDate: daysAgo(8)),
        ])

        XCTAssertEqual(try sut.dueForReview(limit: 1).map(\.id), [card2.id])
        XCTAssertEqual(try sut.dueForReview(limit: 2).map(\.id), [card2.id, card1.id])
        XCTAssertEqual(try sut.dueForReview(limit: 99).count, 3, "A limit above the due count returns everything that is due.")
    }

    func test_characterization_dueForReview_skipsBoxesThatAreNotDueYet() throws {
        let sut = makeSUT(boxAmount: 3)
        let (dueCard, notDueCard) = (makeCard(), makeCard())

        sut.loadBoxes(boxes: [
            makeBox(cards: [], reviewInterval: 0, lastReviewedDate: daysAgo(0)),
            makeBox(cards: [dueCard], reviewInterval: 3, lastReviewedDate: daysAgo(4)),
            makeBox(cards: [notDueCard], reviewInterval: 7, lastReviewedDate: daysAgo(1)),
        ])

        XCTAssertEqual(try sut.dueForReview(limit: 10).map(\.id), [dueCard.id])
    }

    // MARK: - 4. `dueForReview` throws when nothing is due

    func test_characterization_dueForReview_throwsWhenSystemIsEmpty() {
        let sut = makeSUT()

        XCTAssertThrowsError(try sut.dueForReview()) { error in
            XCTAssertEqual(
                error as? LeitnerError,
                .reviewProcessError(reason: "No cards are due for review."),
                "The consumer app relies on this throwing instead of returning an empty array."
            )
        }
    }

    func test_characterization_dueForReview_throwsWhenEveryBoxWithCardsIsNotDue() {
        let sut = makeSUT(boxAmount: 3)

        sut.loadBoxes(boxes: [
            makeBox(cards: [], reviewInterval: 0, lastReviewedDate: daysAgo(0)),
            makeBox(cards: [makeCard()], reviewInterval: 3, lastReviewedDate: daysAgo(1)),
            makeBox(cards: [makeCard()], reviewInterval: 7, lastReviewedDate: daysAgo(1)),
        ])

        XCTAssertThrowsError(try sut.dueForReview())
    }

    // MARK: - 5. A correct answer in the last box retires the card

    func test_characterization_correctAnswerInLastBox_retiresCardFromSystem() throws {
        let sut = makeSUT()
        let retired = makeCard()
        let staying = makeCard()
        sut.addCard(retired)
        sut.addCard(staying)
        try moveCardForward(card: retired, to: 4, in: sut)
        XCTAssertEqual(sut.cardCountsPerBox, [1, 0, 0, 0, 1])

        try sut.updateCard(retired, correct: true)

        XCTAssertEqual(sut.cardCountsPerBox, [1, 0, 0, 0, 0], "The retired card is gone from every box; only the untouched card remains.")
        XCTAssertFalse(sut.allBoxes.flatMap(\.cards).contains { $0.id == retired.id })
        XCTAssertThrowsError(try sut.updateCard(retired, correct: true)) { error in
            XCTAssertEqual(error as? LeitnerError, .cardNotFound, "A retired card is no longer known to the system.")
        }
    }

    // MARK: - 6. `allBoxes` snapshot + `loadBoxes` restores the exact state (the app's undo)

    func test_characterization_snapshotOfAllBoxes_restoresExactStateViaLoadBoxes() throws {
        let sut = makeSUT()
        let cards = (0..<4).map { _ in makeCard() }
        cards.forEach(sut.addCard)
        try moveCardForward(card: cards[0], to: 2, in: sut)
        try moveCardForward(card: cards[1], to: 1, in: sut)

        let snapshot = sut.allBoxes
        let dueBeforeUndo = try sut.dueForReview(limit: 99).map(\.id)

        // Answer a few more cards, then undo by restoring the snapshot.
        try sut.updateCard(cards[0], correct: true)
        try sut.updateCard(cards[2], correct: true)
        try sut.updateCard(cards[3], correct: false)
        sut.loadBoxes(boxes: snapshot)

        assertBoxes(sut.allBoxes, matches: snapshot)
        XCTAssertEqual(try sut.dueForReview(limit: 99).map(\.id), dueBeforeUndo, "Undo has to restore the due set as well, not just box membership.")
    }

    func test_characterization_snapshotOfAllBoxes_restoresRetiredCard() throws {
        let sut = makeSUT()
        let card = makeCard()
        sut.addCard(card)
        try moveCardForward(card: card, to: 4, in: sut)

        let snapshot = sut.allBoxes
        try sut.updateCard(card, correct: true)
        XCTAssertEqual(sut.cardCountsPerBox, [0, 0, 0, 0, 0])

        sut.loadBoxes(boxes: snapshot)

        assertBoxes(sut.allBoxes, matches: snapshot)
        XCTAssertEqual(sut.cardCountsPerBox, [0, 0, 0, 0, 1], "Undoing a retirement brings the card back into the last box.")
    }

    // MARK: - 7. The consumer app's demo setup

    /// Mirrors `DemoContent.boxes(...)` in the `wordlern` app: five boxes, the
    /// session box (index 1) backdated past its own interval so it is due, every
    /// other box reviewed today. Box 0 is due anyway because its interval is 0.
    func test_characterization_demoContentSetup_duesOnlyTheSessionBoxAndBoxZero() throws {
        let sut = makeSUT()
        let intervals: [TimeInterval] = [0, 3, 7, 14, 30]
        let sessionBoxIndex = 1
        let cardsPerBox = (0..<5).map { _ in [makeCard(), makeCard()] }

        sut.loadBoxes(boxes: (0..<5).map { index in
            let interval = intervals[index]
            return makeBox(
                cards: cardsPerBox[index],
                reviewInterval: interval,
                lastReviewedDate: index == sessionBoxIndex ? daysAgo(Int(interval) + 1) : daysAgo(0)
            )
        })

        let due = try sut.dueForReview(limit: 99)

        XCTAssertEqual(
            due.map(\.id),
            (cardsPerBox[sessionBoxIndex] + cardsPerBox[0]).map(\.id),
            "Only the backdated session box and box 0 are due, session box first."
        )
    }

    // MARK: - 8. Default review intervals

    func test_characterization_defaultBoxCountAndIntervals() {
        let sut = makeSUT()

        XCTAssertEqual(sut.allBoxes.count, 5)
        XCTAssertEqual(sut.allBoxes.map(\.reviewInterval), [0, 3, 7, 14, 30], "These intervals are shown to the user in the app's \"How it works\" screen.")
    }

    func test_characterization_intervalsForSevenBoxes_doubleTheLastBaseInterval() {
        let sut = makeSUT(boxAmount: 7)

        XCTAssertEqual(sut.allBoxes.map(\.reviewInterval), [0, 3, 7, 14, 30, 60, 120])
    }

    // MARK: - Test Helpers

    private func makeSUT(boxAmount: UInt? = nil) -> LeitnerSystem {
        boxAmount != nil ? LeitnerSystem(boxAmount: boxAmount!) : LeitnerSystem()
    }

    private func moveCardForward(card: Card, to boxIndex: Int, in sut: LeitnerSystem) throws {
        for _ in 0..<boxIndex {
            try sut.updateCard(card, correct: true)
        }
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

    /// `Box` and `Card` are not `Equatable` (adding conformances is out of scope
    /// for this plan), so compare the fields that make up the system's state.
    private func assertBoxes(
        _ boxes: [Box],
        matches expected: [Box],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(boxes.count, expected.count, "box count", file: file, line: line)
        for (index, (box, expectedBox)) in zip(boxes, expected).enumerated() {
            XCTAssertEqual(box.cards.map(\.id), expectedBox.cards.map(\.id), "cards in box \(index)", file: file, line: line)
            XCTAssertEqual(box.reviewInterval, expectedBox.reviewInterval, "interval of box \(index)", file: file, line: line)
            XCTAssertEqual(box.lastReviewedDate, expectedBox.lastReviewedDate, "lastReviewedDate of box \(index)", file: file, line: line)
        }
    }
}
