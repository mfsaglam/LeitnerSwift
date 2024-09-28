//
//  LeitnerSystemTest.swift
//  LeitnerAlgorithmTests
//
//  Created by Fatih Sağlam on 8.09.2024.
//

import Foundation
import XCTest
@testable import LeitnerSwift

class LeitnerFlowTest: XCTestCase {
    
    func test_init_canNotBecreatedWithZeroAmountOfBoxes() {
        let sut = makeSUT(boxAmount: 0)
        XCTAssert(!sut.boxes.isEmpty, "System can not be created with 0 amount of boxes.")
    }
    
    func test_init_canNotBecreatedWithOneBox() {
        let sut = makeSUT(boxAmount: 1)
        XCTAssertEqual(sut.boxes.count, 2, "System can not be created with 0 amount of boxes.")
    }
    
    func test_defaultInitializer_createsFiveBoxes() {
        let sut = makeSUT()
        XCTAssertEqual(sut.boxes.count, 5, "The system should initialize with 5 boxes by default.")
    }

    func test_init_createsWithGivenAmountOfBoxes() {
        let sut2 = makeSUT(boxAmount: 2)
        XCTAssertEqual(sut2.boxes.count, 2)
        
        let sut3 = makeSUT(boxAmount: 3)
        XCTAssertEqual(sut3.boxes.count, 3)
        
        let sut10 = makeSUT(boxAmount: 10)
        XCTAssertEqual(sut10.boxes.count, 10)
        
        let sut21 = makeSUT(boxAmount: 21)
        XCTAssertEqual(sut21.boxes.count, 21)
    }
    
    func test_init_createsBoxesNotReviewed() {
        let sut = makeSUT()
        sut.boxes.forEach { box in
            XCTAssertNil(box.lastReviewedDate, "System's boxes should not be reviewed when created.")
        }
    }

    func test_loadBoxes() {
        let sut = makeSUT(boxAmount: 3)
        
        let card1 = makeCard(with: UUID())
        let card2 = makeCard(with: UUID())
        let newBoxes = [
            makeBox(cards: [card1]),
            makeBox(cards: [card2]),
            makeBox(cards: [])
        ]
        sut.loadBoxes(boxes: newBoxes)
        
        XCTAssertEqual(sut.boxes.count, 3)
        XCTAssertEqual(sut.boxes[0].cards.count, 1)
        XCTAssertEqual(sut.boxes[1].cards.count, 1)
        XCTAssertEqual(sut.boxes[2].cards.count, 0)
        XCTAssertEqual(sut.boxes[0].cards.first?.id, card1.id)
        XCTAssertEqual(sut.boxes[1].cards.first?.id, card2.id)
    }

    func test_reviewIntervals_withDefaultBoxes() {
        let sut = makeSUT()
        
        let expectedIntervals: [TimeInterval] = [1, 3, 7, 14, 30]
        for (index, box) in sut.boxes.enumerated() {
            XCTAssertEqual(box.reviewInterval, expectedIntervals[index], "The review interval for box \(index + 1) should be \(expectedIntervals[index]).")
        }
    }
    
    func test_reviewIntervals_withMoreBoxes() {
        let sut = makeSUT(boxAmount: 7)
        
        let expectedIntervals: [TimeInterval] = [1, 3, 7, 14, 30, 60, 120]
        for (index, box) in sut.boxes.enumerated() {
            XCTAssertEqual(box.reviewInterval, expectedIntervals[index], "The review interval for box \(index + 1) should be \(expectedIntervals[index]).")
        }
    }
    
    func test_reviewIntervals_withLessThanTwoBoxes_usesTwoReviewIntervals() {
        let sut = makeSUT(boxAmount: 1)
        
        let expectedIntervals: [TimeInterval] = [1, 3]  // Only two intervals since there are two boxes
        for (index, box) in sut.boxes.enumerated() {
            XCTAssertEqual(box.reviewInterval, expectedIntervals[index], "The review interval for box \(index + 1) should be \(expectedIntervals[index]).")
        }
    }

    func test_addCard_addsToFirstBox() {
        let sut = makeSUT()
        
        let id = fixedUuid
        let card = makeCard(with: id)
        sut.addCard(card)

        XCTAssertEqual(sut.boxes[0].cards.count, 1, "The first box should contain the card after it's added.")
        XCTAssertEqual(sut.boxes[0].cards.first?.id, id, "The first box should contain the card after it's added.")
    }
    
    func test_cardInFirstBox_correctAnswer_movesCardToSecondBox() {
        let sut = makeSUT()
        
        let id = fixedUuid
        let card = makeCard(with: id)
        sut.addCard(card)
        
        sut.updateCard(card, correct: true)
        
        XCTAssertEqual(sut.boxes[0].cards.count, 0, "The first box should be empty.")
        XCTAssertEqual(sut.boxes[1].cards.first?.id, id, "The second box should contain the card just moved.")
    }
    
    func test_cardInSecondBox_correctAnswer_movesCardToThirdBox() {
        let sut = makeSUT()
        
        let id = fixedUuid
        let card = makeCard(with: id)
        sut.addCard(card)
        
        // Move the card to the second box manually
        moveCardForward(card: card, to: 1, in: sut)

        sut.updateCard(card, correct: true)
        
        XCTAssertEqual(sut.boxes[0].cards.count, 0, "The first box should be empty.")
        XCTAssertEqual(sut.boxes[1].cards.count, 0, "The second box should be empty.")
        XCTAssertEqual(sut.boxes[2].cards.first?.id, id, "The next(third) box should contain the card just moved.")
    }
    
    func test_cardInLastBox_correctAnswer_retiresTheCardFromSystem() {
        let sut = makeSUT()
        
        let id = fixedUuid
        let card = makeCard(with: id)
        sut.addCard(card)
        // Move the card to the last box manually
        moveCardForward(card: card, to: 4, in: sut)
        
        sut.updateCard(card, correct: true)
        
        XCTAssertEqual(sut.boxes[4].cards.count, 0, "The last box should remove the card from system after a correct answer.")
    }
    
    func test_cardInFirstBox_incorrectAnswer_keepsCardInFirstBox() {
        let sut = makeSUT()
        
        let id = fixedUuid
        let card = makeCard(with: id)
        sut.addCard(card)
        
        sut.updateCard(card, correct: false)
        
        XCTAssertEqual(sut.boxes[0].cards.count, 1, "The first box should still contain the card after an incorrect answer.")
        XCTAssertEqual(sut.boxes[0].cards.first?.id, id, "The card should not move after an incorrect answer in the first box.")
    }
    
    func test_cardInSecondBox_incorrectAnswer_movesCardBackToFirstBox() {
        let sut = makeSUT()

        let id = fixedUuid
        let card = makeCard(with: id)
        sut.addCard(card)
        // Move the card to the second box manually
        moveCardForward(card: card, to: 1, in: sut)
        
        sut.updateCard(card, correct: false)
        
        XCTAssertEqual(sut.boxes[1].cards.count, 0, "The second box should be empty after an incorrect answer.")
        XCTAssertEqual(sut.boxes[0].cards.first?.id, id, "The card should move back to the first box after an incorrect answer.")
    }
    
    func test_cardInLastBox_incorrectAnswer_movesCardToFirstBox() {
        let sut = makeSUT()

        let id = fixedUuid
        let card = makeCard(with: id)
        sut.addCard(card)
        // Move the card to the last box manually
        moveCardForward(card: card, to: 4, in: sut)
        
        sut.updateCard(card, correct: false)
        
        XCTAssertEqual(sut.boxes[4].cards.count, 0, "The last box should be empty after an incorrect answer.")
        XCTAssertEqual(sut.boxes[0].cards.first?.id, id, "The card should move back to the previous box after an incorrect answer.")
    }
    
    func test_lastReviewedDateUpdated_whenBoxIsFullyReviewed() {
        let sut = makeSUT(boxAmount: 3) // 3 boxes for this test
        let card1 = makeCard(with: UUID())
        let card2 = makeCard(with: UUID())
        
        sut.addCard(card1)
        sut.addCard(card2)
        
        // When: Both cards in the first box are answered correctly
        sut.updateCard(card1, correct: true) // Moves to the next box
        sut.updateCard(card2, correct: true) // Moves to the next box, now the box should be empty
        
        // Then: The first box should have its lastReviewedDate updated
        let firstBox = sut.boxes[0]
        XCTAssertEqual(firstBox.cards.isEmpty, true, "First box should be empty after all cards are moved.")
        XCTAssertNotNil(firstBox.lastReviewedDate, "First box's lastReviewedDate should be updated after full review.")
    }

    func test_lastReviewedDateNotUpdated_whenBoxNotFullyReviewed() {
        let sut = LeitnerSystem(boxAmount: 3)
        let card1 = makeCard(with: UUID())
        let card2 = makeCard(with: UUID())
        
        sut.addCard(card1)
        sut.addCard(card2)
        
        // When: Only one card is answered correctly
        sut.updateCard(card1, correct: true) // Moves to the next box
        
        // Then: The first box's lastReviewedDate should not be updated, as it still has one card left
        let firstBox = sut.boxes[0]
        XCTAssertEqual(firstBox.cards.count, 1, "First box should still have one card.")
        XCTAssertNil(firstBox.lastReviewedDate, "First box's lastReviewedDate should not be updated while there are still cards to review.")
    }

    func test_dueForReview_returnsDueCards() {
        let sut = makeSUT()
        
        let pastDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())! // 2 days in the past
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())! // 1 day in the future
        
        let card1 = makeCard(with: UUID())
        let card2 = makeCard(with: UUID())
        
        sut.loadBoxes(
            boxes: [
                makeBox(cards: [card1], lastReviewedDate: pastDate), // Due for review
                makeBox(cards: [card2], lastReviewedDate: futureDate) // Not due
            ]
        )
        
        let result = sut.dueForReview(limit: 1)
        
        XCTAssertEqual(result.count, 1, "Expected 1 card due for review, got \(result.count)")
        XCTAssertEqual(result.first?.id, card1.id, "Expected the first card to be due for review.")
    }
    
    func test_dueForReview_returnsDueCardsIfTheLastReviewDateIsToday() {
        let sut = makeSUT()

        let card1 = makeCard(with: UUID())
        
        sut.loadBoxes(
            boxes: [
                makeBox(cards: [card1], reviewInterval: 0, lastReviewedDate: fixedDate) // Due for review
            ]
        )
        
        let result = sut.dueForReview()
        
        XCTAssertEqual(result.count, 1, "Expected 1 card due for review, got \(result.count)")
        XCTAssertEqual(result.first?.id, card1.id, "Expected the first card to be due for review.")
    }
    
    func test_dueForReview_limitsReturnedCards() {
        let sut = makeSUT()
        
        let pastDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())! // 2 days in the past
        
        // Create 3 cards, all due for review
        let card1 = makeCard(with: UUID())
        let card2 = makeCard(with: UUID())
        let card3 = makeCard(with: UUID())
        
        sut.loadBoxes(
            boxes: [
                makeBox(cards: [card1, card2, card3], lastReviewedDate: pastDate), // Due for review
            ]
        )
        
        let result = sut.dueForReview(limit: 2)
        
        XCTAssertEqual(result.count, 2, "Expected to fetch only 2 cards due for review, got \(result.count)")
    }
    
    func test_dueForReview_noDueCards_returnsEmpty() {
        let sut = makeSUT()
        
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())! // 1 day in the past
        
        // Create 3 cards
        let card1 = makeCard(with: UUID())
        let card2 = makeCard(with: UUID())
        let card3 = makeCard(with: UUID())
        
        sut.loadBoxes(
            boxes: [
                makeBox(cards: [card1, card2, card3], reviewInterval: 2, lastReviewedDate: pastDate), // Not due for review
            ]
        )
        
        let result = sut.dueForReview()
        
        XCTAssertTrue(result.isEmpty, "Expected to fetch none, got \(result.count)")
    }

     // MARK: - Test Helpers
    
    private func makeSUT(boxAmount: UInt? = nil) -> LeitnerSystem {
        return boxAmount != nil ? LeitnerSystem(boxAmount: boxAmount!) : LeitnerSystem()
    }
    
    private func moveCardForward(card: Card, to boxIndex: Int, in sut: LeitnerSystem) {
        for _ in 0..<boxIndex {
            sut.updateCard(card, correct: true)
        }
    }
    
    private func makeBox(
        cards: [Card] = [],
        reviewInterval: TimeInterval = 1,
        lastReviewedDate: Date = Date(timeIntervalSince1970: 0)
    ) -> Box {
        .init(cards: cards, reviewInterval: reviewInterval, lastReviewedDate: lastReviewedDate)
    }
    
    private func makeCard(
        with id: UUID
    ) -> Card {
        let word = makeWord()
        return Card(id: id, word: word)
    }
    
    private func makeWord(
        word: String = "defaultWord",
        languageCode: String = "en",
        meaning: String = "defaultMeaning",
        exampleSentence: String? = nil
    ) -> Word {
        return Word(
            word: word,
            languageCode: languageCode,
            meaning: meaning,
            exampleSentence: exampleSentence
        )
    }
    
    private var fixedUuid: UUID {
        return UUID(uuidString: "2A8DDD36-50D3-458A-A2BF-B0A1E36C1759")!
    }

    private var fixedDate: Date {
        return Date(timeIntervalSince1970: 0)  // Fixed date for testing
    }
}
