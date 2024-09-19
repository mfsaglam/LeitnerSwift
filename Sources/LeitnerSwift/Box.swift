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
    public var lastReviewedDate: Date
    
    public var nextReviewDate: Date {
        return Calendar.current.date(byAdding: .day, value: Int(reviewInterval), to: lastReviewedDate) ?? Date()
    }
}
