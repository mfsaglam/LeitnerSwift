//
//  Card.swift
//  LeitnerAlgorithm
//
//  Created by Fatih Sağlam on 8.09.2024.
//

import Foundation

public struct Card {
    public let id: UUID
    public let word: Word

    /// The date this card was last answered, used together with its box's
    /// `reviewInterval` to decide when the card becomes due again.
    /// `nil` means the card has never been reviewed, which makes it due right away.
    public internal(set) var lastReviewedDate: Date?

    public init(
        id: UUID = UUID(),
        word: Word,
        lastReviewedDate: Date? = nil
    ) {
        self.id = id
        self.word = word
        self.lastReviewedDate = lastReviewedDate
    }
}
