//
//  LeitnerSystem.swift
//  LeitnerAlgorithm
//
//  Created by Fatih Sağlam on 8.09.2024.
//

import Foundation

public class LeitnerSystem {
    private(set) var boxes: [Box]
    
    /// Initializes the Leitner system with a specified number of boxes.
    /// Each box will have a different review interval based on the Leitner algorithm.
    /// If the provided box amount is less than 2, it defaults to 2 boxes.
    /// Each box starts empty and with its `lastReviewedDate` set to the current date.
    ///
    /// - Parameter boxAmount: The number of boxes to create. Defaults to 5.
    ///   Must be at least 2 to ensure the system works as expected.
    public init(boxAmount: UInt = 5) {
        let boxCount = max(2, Int(boxAmount))  // Ensure at least 2 boxes
        let reviewIntervals = LeitnerSystem.generateReviewIntervals(for: boxCount)
        
        boxes = (0..<boxCount).map { index in
            Box(
                cards: [],
                reviewInterval: TimeInterval(reviewIntervals[index]),
                lastReviewedDate: nil
            )
        }
    }
    
    /// Adds a new card to the Leitner system, placing it in the first box.
    /// The card will always start in the first box, and its progress will be tracked from there.
    ///
    /// - Parameter card: The `Card` object to be added to the first box for review.
    public func addCard(_ card: Card) {
        boxes[0].cards.append(card)  // Start card in the first box
    }
    
    /// Updates the review status of a card and moves it to the appropriate box based on the correctness of the user's response.
    /// If the answer is correct, the card moves to the next box; if incorrect, it moves back to the first box.
    ///
    /// - Parameters:
    ///   - card: The `Card` object to be updated. This is passed as an inout parameter to allow modification.
    ///   - correct: A Boolean indicating whether the user's answer was correct. If `true`, the card progresses to the next box; if `false`, it returns to the first box.
    public func updateCard(_ card: Card, correct: Bool) {
        // Find the card's current box
        for (boxIndex, box) in boxes.enumerated() {
            if let index = box.cards.firstIndex(where: { $0.id == card.id }) {
                // Remove the card from the current box
                boxes[boxIndex].cards.remove(at: index)
                
                if correct {
                    // If the card is in the last box, remove it from the system
                    if boxIndex == boxes.count - 1 {
                        // Card has been correctly answered and is in the last box, so it is removed completely
                        return
                    } else {
                        // Otherwise, move the card to the next box
                        let nextBox = boxIndex + 1
                        appendCard(card, to: nextBox)
                    }
                } else {
                    // If the answer is incorrect, move the card back to the first box
                    appendCard(card, to: 0)
                }
                updateLastReviewedDateIfNeeded(for: boxIndex)
                break
            }
        }
    }
    
    // Function to check and update the box's lastReviewedDate
    private func updateLastReviewedDateIfNeeded(for boxIndex: Int) {
        // If the box is empty, mark it as reviewed
        if boxes[boxIndex].cards.isEmpty {
            boxes[boxIndex].lastReviewedDate = Date() // Set the last reviewed date to now
        }
    }
    
    /// Retrieves a list of cards that are due for review, up to a specified limit.
    /// Only cards with a review date on or before the current date are considered due for review.
    ///
    /// - Parameter limit: The maximum number of due cards to return. The default value is 10. If more cards are due, only the first `limit` number are returned.
    /// - Returns: An array of `Card` objects that are due for review, limited to the specified `limit`.
    public func dueForReview(limit: Int = 10) -> [Card] {
        let today = Calendar.current.startOfDay(for: Date())
        var dueCards: [Card] = []
        
        for box in boxes where box.nextReviewDate <= today {
            dueCards.append(contentsOf: box.cards)
        }
        
        return Array(dueCards.prefix(limit))
    }
    
    /// Loads an existing set of boxes into the Leitner system.
    /// This method replaces the current boxes with the provided ones.
    /// Typically used when reloading a previously saved state of the Leitner system from storage.
    ///
    /// - Parameter boxes: An array of `Box` objects, each representing a box with its cards,
    ///   review interval, and last reviewed date.
    public func loadBoxes(boxes: [Box]) {
        self.boxes = boxes
    }

    // Generates review intervals based on the number of boxes
    static private func generateReviewIntervals(for boxCount: Int) -> [Int] {
        let baseIntervals = [1, 3, 7, 14, 30, 60]
        var intervals = [Int]()
        
        for i in 0..<boxCount {
            if i < baseIntervals.count {
                intervals.append(baseIntervals[i])
            } else {
                // Extend the intervals for more boxes (e.g., double the last one or add a custom logic)
                let extendedInterval = intervals.last! * 2  // Example: extend by doubling the last interval
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
