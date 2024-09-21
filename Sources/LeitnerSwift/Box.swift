//
//  Box.swift
//  LeitnerAlgorithm
//
//  Created by Fatih Sağlam on 15.09.2024.
//

import Foundation

public struct Box {
    public var cards: [Card]
    public var reviewInterval: TimeInterval
    public var lastReviewedDate: Date?
    
    public init(
        cards: [Card],
        reviewInterval: TimeInterval,
        lastReviewedDate: Date?
    ) {
        self.cards = cards
        self.reviewInterval = reviewInterval
        self.lastReviewedDate = lastReviewedDate
    }
    
    public var nextReviewDate: Date {
        guard let lastReviewedDate else { return Date() }
        return Calendar.current.date(byAdding: .day, value: Int(reviewInterval), to: lastReviewedDate) ?? Date()
    }
}
