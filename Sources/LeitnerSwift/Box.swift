//
//  Box.swift
//  LeitnerAlgorithm
//
//  Created by Fatih Sağlam on 15.09.2024.
//

import Foundation

struct Box {
    var cards: [Card]
    var reviewInterval: TimeInterval
    var lastReviewedDate: Date
    
    var nextReviewDate: Date {
        return Calendar.current.date(byAdding: .day, value: Int(reviewInterval), to: lastReviewedDate) ?? Date()
    }
}
