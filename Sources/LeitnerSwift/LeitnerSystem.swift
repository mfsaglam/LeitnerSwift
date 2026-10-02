//
//  LeitnerSystem.swift
//  LeitnerAlgorithm
//
//  Created by Fatih Sağlam on 8.09.2024.
//

import Foundation

public class LeitnerSystem {
    private(set) var boxes: [Box]
    private let dateProvider: () -> Date

    /// Initializes the Leitner system with a specified number of boxes.
    /// Each box will have a different review interval based on the Leitner algorithm.
    /// If the provided box amount is less than 2, it defaults to 2 boxes.
    /// Each box starts empty and with its `lastReviewedDate` set to the current date.
    ///
    /// - Parameters:
    ///   - boxAmount: The number of boxes to create. Defaults to 5.
    ///     Must be at least 2 to ensure the system works as expected.
    ///   - dateProvider: A closure providing the current date. Defaults to `Date()`.
    ///     Injectable for testing time-dependent behavior.
    public init(boxAmount: UInt = 5, dateProvider: @escaping () -> Date = { Date() }) {
        let boxCount = max(2, Int(boxAmount))  // Ensure at least 2 boxes
        let reviewIntervals = LeitnerSystem.generateReviewIntervals(for: boxCount)
        self.dateProvider = dateProvider

        boxes = (0..<boxCount).map { index in
            let initialLastReviewedDate: Date? = dateProvider()
            return Box(
                cards: [],
                reviewInterval: TimeInterval(reviewIntervals[index]),
                lastReviewedDate: initialLastReviewedDate
            )
        }
    }

    /// A read-only property that provides access to the array of `Box` objects in the system.
    ///
    /// `allBoxes` allows external clients to retrieve the current state of all boxes in the
    /// Leitner system, which can be used to save or display progress. This property provides
    /// a copy of the internal `boxes` array, ensuring that clients can access the current
    /// state without the ability to modify the underlying data, preserving the system's integrity.
    public var allBoxes: [Box] {
        return boxes
    }
    
    /// Adds a new card to the Leitner system, placing it in the first box.
    /// The card will always start in the first box, and its progress will be tracked from there.
    ///
    /// - Parameter card: The `Card` object to be added to the first box for review.
    public func addCard(_ card: Card) {
        guard !boxes.isEmpty else { return }
        guard !boxes.contains(where: { $0.cards.contains(where: { $0.id == card.id }) }) else { return }
        boxes[0].cards.append(card)  // Start card in the first box
    }
    
    /// Updates the review status of a card and moves it to the appropriate box based on the correctness of the user's response.
    /// If the answer is correct, the card moves to the next box; if incorrect, it moves back to the first box.
    ///
    /// - Parameters:
    ///   - card: The `Card` object to be updated.
    ///   - correct: A Boolean indicating whether the user's answer was correct. If `true`, the card progresses to the next box; if `false`, it returns to the first box.
    public func updateCard(_ card: Card, correct: Bool) throws {
        guard !boxes.isEmpty else {
            throw LeitnerError.cardNotFound
        }
        // Find the card's current box
        var cardFound = false
        for (boxIndex, box) in boxes.enumerated() {
            if let index = box.cards.firstIndex(where: { $0.id == card.id }) {
                // Remove the card from the current box, stamping it as reviewed now.
                // The stamp is what schedules the card in its next box, so it is
                // applied no matter which way the card moves.
                var reviewedCard = boxes[boxIndex].cards[index]
                reviewedCard.lastReviewedDate = dateProvider()
                boxes[boxIndex].cards.remove(at: index)
                cardFound = true

                if correct {
                    // If the card is in the last box, remove it from the system
                    if boxIndex == boxes.count - 1 {
                        // Card has been correctly answered and is in the last box, so it is removed completely
                        updateLastReviewedDateIfNeeded(for: boxIndex)
                        return
                    } else {
                        // Otherwise, move the card to the next box
                        let nextBox = boxIndex + 1
                        appendCard(reviewedCard, to: nextBox)
                    }
                } else {
                    // If the answer is incorrect, move the card back to the first box
                    appendCard(reviewedCard, to: 0)
                }
                updateLastReviewedDateIfNeeded(for: boxIndex)
                break
            }
        }
        if !cardFound {
            throw LeitnerError.cardNotFound
        }
    }
    
    // Function to check and update the box's lastReviewedDate
    private func updateLastReviewedDateIfNeeded(for boxIndex: Int) {
        // If the box is empty, mark it as reviewed
        if boxes[boxIndex].cards.isEmpty {
            boxes[boxIndex].lastReviewedDate = dateProvider() // Set the last reviewed date to now
        }
    }
    
    /// Retrieves a list of cards that are due for review, up to a specified limit.
    /// Only cards with a review date on or before the current date are considered due for review.
    ///
    /// - Parameter limit: The maximum number of due cards to return. The default value is 10. If more cards are due, only the first `limit` number are returned.
    /// - Returns: An array of `Card` objects that are due for review, limited to the specified `limit`.
    public func dueForReview(limit: Int = 10) throws -> [Card] {
        let today = Calendar.current.startOfDay(for: dateProvider())
        var dueCards: [Card] = []

        for box in boxes.reversed() {
            dueCards.append(contentsOf: box.cards.filter { isDue($0, in: box, asOf: today) })
        }

        if dueCards.isEmpty {
            throw LeitnerError.reviewProcessError(reason: "No cards are due for review.")
        }
        
        return Array(dueCards.prefix(max(0, limit)))
    }
    
    /// Loads an existing set of boxes into the Leitner system.
    /// This method replaces the current boxes with the provided ones.
    /// Typically used when reloading a previously saved state of the Leitner system from storage.
    ///
    /// Cards that carry no `lastReviewedDate` inherit the one of the box they are
    /// loaded into. Storage that predates card-level scheduling therefore keeps
    /// behaving exactly as it did when scheduling was box-level.
    ///
    /// - Parameter boxes: An array of `Box` objects, each representing a box with its cards,
    ///   review interval, and last reviewed date.
    public func loadBoxes(boxes: [Box]) {
        self.boxes = boxes.map { box in
            guard box.cards.contains(where: { $0.lastReviewedDate == nil }) else { return box }
            var stampedBox = box
            stampedBox.cards = box.cards.map { card in
                guard card.lastReviewedDate == nil else { return card }
                var stampedCard = card
                stampedCard.lastReviewedDate = box.lastReviewedDate
                return stampedCard
            }
            return stampedBox
        }
    }

    /// The date a card becomes due again: its own last review stamp pushed forward
    /// by the review interval of the box it currently sits in.
    /// `nil` means the card has never been reviewed, so it is due immediately.
    private func nextReviewDate(of card: Card, in box: Box) -> Date? {
        guard let lastReviewedDate = card.lastReviewedDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: Int(box.reviewInterval), to: lastReviewedDate)
    }

    private func isDue(_ card: Card, in box: Box, asOf startOfToday: Date) -> Bool {
        guard let nextReviewDate = nextReviewDate(of: card, in: box) else { return true }
        return Calendar.current.startOfDay(for: nextReviewDate) <= startOfToday
    }

    public var cardCountsPerBox: [Int] {
        return boxes.map { $0.cards.count }
    }

    /// Counts the cards that are due for review as of a given date, using the same
    /// card-level logic as `dueForReview`.
    ///
    /// - Parameter date: The date to evaluate "due" against.
    /// - Returns: The total number of cards whose own next review date is on or before `date`.
    public func dueCount(asOf date: Date) -> Int {
        let today = Calendar.current.startOfDay(for: date)
        return boxes.reduce(0) { result, box in
            result + box.cards.filter { isDue($0, in: box, asOf: today) }.count
        }
    }

    /// The number of cards due for review as of now (via `dateProvider`).
    public var dueCount: Int {
        dueCount(asOf: dateProvider())
    }

    /// The earliest next review date among the cards still in the system.
    /// `nil` whenever `dueCount` is greater than zero, since there is nothing to wait for.
    public var nextDueDate: Date? {
        guard dueCount == 0 else { return nil }
        return boxes.flatMap { box in box.cards.compactMap { nextReviewDate(of: $0, in: box) } }.min()
    }

    // Generates review intervals based on the number of boxes
    static private func generateReviewIntervals(for boxCount: Int) -> [Int] {
        let baseIntervals = [0, 3, 7, 14, 30, 60]
        var intervals = [Int]()
        
        for i in 0..<boxCount {
            if i < baseIntervals.count {
                intervals.append(baseIntervals[i])
            } else {
                // Extend the intervals for more boxes (e.g., double the last one or add a custom logic)
                let extendedInterval = min(intervals.last! * 2, 365)  // Example: extend by doubling the last interval, capped to avoid overflow
                intervals.append(extendedInterval)
            }
        }
        
        return intervals
    }

    private func appendCard(_ card: Card, to boxIndex: Int) {
        // Move the card to the target box
        boxes[boxIndex].cards.append(card)
    }
}
