//
//  Card.swift
//  LeitnerAlgorithm
//
//  Created by Fatih Sağlam on 8.09.2024.
//

import Foundation

struct Card {
    let id: UUID
    let word: Word
    
    init(
        id: UUID = UUID(),
        word: Word
    ) {
        self.id = id
        self.word = word
    }
}
