//
//  CardLevelSchedulingTests.swift
//  LeitnerSwiftTests
//
//  Covers ROADMAP step 7 (B1): scheduling lives on the card, not on the box, so a
//  card promoted into a box that was reviewed long ago no longer inherits that
//  box's stale date and come back due the very same second.
//

import Foundation
import XCTest
@testable import LeitnerSwift

final class CardLevelSchedulingTests: XCTestCase {

    // MARK: - B1: a promoted card waits out its new box's interval

    func test_cardPromotedIntoStaleBox_isNotDueToday_butBecomesDueAfterTheNewBoxInterval() throws {
        var now = Date()
        let sut = LeitnerSystem(boxAmount: 5, dateProvider: { now })
        let card = makeCard()

        // Box 1 (interval 3) was last reviewed 10 days ago: under box-level
        // scheduling the promoted card would be due immediately.
        sut.loadBoxes(boxes: [
            makeBox(cards: [card], reviewInterval: 0, lastReviewedDate: now),
            makeBox(cards: [], reviewInterval: 3, lastReviewedDate: daysAgo(10, from: now)),
            makeBox(cards: [], reviewInterval: 7, lastReviewedDate: daysAgo(10, from: now)),
            makeBox(cards: [], reviewInterval: 14, lastReviewedDate: daysAgo(10, from: now)),
            makeBox(cards: [], reviewInterval: 30, lastReviewedDate: daysAgo(10, from: now)),
        ])

        try sut.updateCard(card, correct: true)

        XCTAssertEqual(sut.cardCountsPerBox, [0, 1, 0, 0, 0])
        XCTAssertEqual(sut.dueCount, 0, "The card was just answered, so it must not be due again today.")
        XCTAssertThrowsError(try sut.dueForReview(), "This is B1: the card used to come straight back.")

        now = daysLater(2, from: now)
        XCTAssertEqual(sut.dueCount, 0, "Still inside box 1's 3 day interval.")

        now = daysLater(1, from: now)
        XCTAssertEqual(sut.dueCount, 1)
        XCTAssertEqual(try sut.dueForReview().map(\.id), [card.id], "Due exactly 3 days after the answer.")
    }

    func test_updateCard_stampsTheCardsLastReviewedDate_whenPromotedAndWhenDemoted() throws {
        var now = Date()
        let sut = LeitnerSystem(boxAmount: 3, dateProvider: { now })
        let card = makeCard()
        sut.addCard(card)
        XCTAssertNil(sut.allBoxes[0].cards[0].lastReviewedDate, "A freshly added card has never been reviewed.")

        try sut.updateCard(card, correct: true)
        XCTAssertEqual(sut.allBoxes[1].cards[0].lastReviewedDate, now, "A promotion stamps the card.")

        now = daysLater(5, from: now)
        try sut.updateCard(card, correct: false)
        XCTAssertEqual(sut.allBoxes[0].cards[0].lastReviewedDate, now, "A demotion stamps the card too.")
    }

    // MARK: - 7.3: loadBoxes stamps un-migrated cards from their box

    func test_loadBoxes_stampsCardsWithoutADate_fromTheirOwnBox() {
        let sut = LeitnerSystem(boxAmount: 2)
        let boxDate = daysAgo(4, from: Date())

        sut.loadBoxes(boxes: [
            makeBox(cards: [makeCard()], reviewInterval: 0, lastReviewedDate: boxDate),
            makeBox(cards: [makeCard()], reviewInterval: 3, lastReviewedDate: boxDate),
        ])

        XCTAssertEqual(sut.allBoxes.map { $0.cards[0].lastReviewedDate }, [boxDate, boxDate])
        XCTAssertEqual(sut.allBoxes.map(\.lastReviewedDate), [boxDate, boxDate], "The box dates themselves are untouched.")
    }

    func test_loadBoxes_keepsDatesOfCardsThatAlreadyHaveOne() {
        let sut = LeitnerSystem(boxAmount: 2)
        let cardDate = daysAgo(1, from: Date())
        let boxDate = daysAgo(9, from: Date())

        sut.loadBoxes(boxes: [
            makeBox(cards: [], reviewInterval: 0, lastReviewedDate: boxDate),
            makeBox(cards: [makeCard(lastReviewedDate: cardDate)], reviewInterval: 3, lastReviewedDate: boxDate),
        ])

        XCTAssertEqual(sut.allBoxes[1].cards[0].lastReviewedDate, cardDate, "Migrated storage wins over the box's date.")
        XCTAssertEqual(sut.dueCount, 0, "The card is scheduled from its own date, not from the box's stale one.")
    }

    /// The whole point of 7.3: data saved before card dates existed keeps behaving
    /// as it did under box-level scheduling.
    func test_unmigratedStorage_duesExactlyTheSameCardsAsBoxLevelSchedulingDid() throws {
        let sut = LeitnerSystem(boxAmount: 3)
        let (dueCard, notDueCard) = (makeCard(), makeCard())

        sut.loadBoxes(boxes: [
            makeBox(cards: [], reviewInterval: 0, lastReviewedDate: daysAgo(0, from: Date())),
            makeBox(cards: [dueCard], reviewInterval: 3, lastReviewedDate: daysAgo(4, from: Date())),
            makeBox(cards: [notDueCard], reviewInterval: 7, lastReviewedDate: daysAgo(1, from: Date())),
        ])

        XCTAssertEqual(try sut.dueForReview(limit: 10).map(\.id), [dueCard.id])
        XCTAssertEqual(sut.dueCount, 1)
    }

    // MARK: - 7.4: due is decided per card, not per box

    func test_dueForReview_returnsOnlyTheDueCardsOfAPartiallyDueBox() throws {
        let sut = LeitnerSystem(boxAmount: 2)
        let dueCard = makeCard(lastReviewedDate: daysAgo(4, from: Date()))
        let notDueCard = makeCard(lastReviewedDate: daysAgo(1, from: Date()))

        sut.loadBoxes(boxes: [
            makeBox(cards: [], reviewInterval: 0, lastReviewedDate: daysAgo(0, from: Date())),
            makeBox(cards: [notDueCard, dueCard], reviewInterval: 3, lastReviewedDate: daysAgo(4, from: Date())),
        ])

        XCTAssertEqual(
            try sut.dueForReview(limit: 10).map(\.id),
            [dueCard.id],
            "The box as a whole is due, but only one of its cards is."
        )
        XCTAssertEqual(sut.dueCount, 1, "dueCount must agree with dueForReview card for card.")
    }

    func test_dueForReview_keepsHigherBoxFirstOrdering_withCardLevelDates() throws {
        let sut = LeitnerSystem(boxAmount: 3)
        let (card0, card1, card2) = (
            makeCard(lastReviewedDate: daysAgo(1, from: Date())),
            makeCard(lastReviewedDate: daysAgo(4, from: Date())),
            makeCard(lastReviewedDate: daysAgo(8, from: Date()))
        )

        sut.loadBoxes(boxes: [
            makeBox(cards: [card0], reviewInterval: 0, lastReviewedDate: daysAgo(1, from: Date())),
            makeBox(cards: [card1], reviewInterval: 3, lastReviewedDate: daysAgo(4, from: Date())),
            makeBox(cards: [card2], reviewInterval: 7, lastReviewedDate: daysAgo(8, from: Date())),
        ])

        XCTAssertEqual(try sut.dueForReview(limit: 10).map(\.id), [card2.id, card1.id, card0.id])
        XCTAssertEqual(try sut.dueForReview(limit: 2).map(\.id), [card2.id, card1.id])
    }

    /// Box 0's interval stays 0 on purpose: a wrong answer has to come back today.
    func test_cardDemotedToBoxZero_isDueAgainTheSameDay() throws {
        var now = Date()
        let sut = LeitnerSystem(boxAmount: 3, dateProvider: { now })
        let card = makeCard()
        sut.addCard(card)
        try sut.updateCard(card, correct: true)

        now = daysLater(5, from: now)
        try sut.updateCard(card, correct: false)

        XCTAssertEqual(try sut.dueForReview().map(\.id), [card.id], "Box 0's zero interval keeps wrong answers due immediately.")
    }

    // MARK: - 7.5: nextDueDate follows the cards

    func test_nextDueDate_isEarliestCardDueDate_notEarliestBoxDueDate() {
        let sut = LeitnerSystem(boxAmount: 2)
        let soonCard = makeCard(lastReviewedDate: daysAgo(2, from: Date()))   // due in 1 day
        let laterCard = makeCard(lastReviewedDate: daysAgo(0, from: Date()))  // due in 3 days
        let staleBoxDate = daysAgo(2, from: Date())

        sut.loadBoxes(boxes: [
            makeBox(cards: [], reviewInterval: 0, lastReviewedDate: daysAgo(0, from: Date())),
            makeBox(cards: [laterCard, soonCard], reviewInterval: 3, lastReviewedDate: staleBoxDate),
        ])

        XCTAssertEqual(sut.dueCount, 0)
        XCTAssertEqual(
            sut.nextDueDate,
            Calendar.current.date(byAdding: .day, value: 3, to: soonCard.lastReviewedDate!),
            "The soonest card decides, even though the box's own nextReviewDate is already in the past."
        )
    }

    func test_nextDueDate_isNil_whenACardIsDue() {
        let sut = LeitnerSystem(boxAmount: 2)
        sut.loadBoxes(boxes: [
            makeBox(cards: [makeCard(lastReviewedDate: daysAgo(4, from: Date()))], reviewInterval: 0, lastReviewedDate: daysAgo(4, from: Date())),
            makeBox(cards: [makeCard(lastReviewedDate: daysAgo(0, from: Date()))], reviewInterval: 3, lastReviewedDate: daysAgo(0, from: Date())),
        ])

        XCTAssertEqual(sut.dueCount, 1)
        XCTAssertNil(sut.nextDueDate)
    }

    // MARK: - Source compatibility

    func test_cardInit_withoutLastReviewedDate_staysSourceCompatible() {
        let card = Card(word: makeWord())
        XCTAssertNil(card.lastReviewedDate)

        let identified = Card(id: UUID(), word: makeWord())
        XCTAssertNil(identified.lastReviewedDate, "The app's `Card(id:word:)` call site must keep compiling unchanged.")
    }

    // MARK: - Test Helpers

    private func makeBox(
        cards: [Card],
        reviewInterval: TimeInterval,
        lastReviewedDate: Date?
    ) -> Box {
        .init(cards: cards, reviewInterval: reviewInterval, lastReviewedDate: lastReviewedDate)
    }

    private func makeCard(id: UUID = UUID(), lastReviewedDate: Date? = nil) -> Card {
        Card(id: id, word: makeWord(), lastReviewedDate: lastReviewedDate)
    }

    private func makeWord() -> Word {
        Word(word: "defaultWord", languageCode: "en", meaning: "defaultMeaning", exampleSentence: nil)
    }

    private func daysAgo(_ days: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: date)!
    }

    private func daysLater(_ days: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date)!
    }
}
