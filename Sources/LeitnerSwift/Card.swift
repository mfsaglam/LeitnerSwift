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
    
    public init(
        id: UUID = UUID(),
        word: Word
    ) {
        self.id = id
        self.word = word
    }
}
