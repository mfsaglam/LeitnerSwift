//
//  Word.swift
//  LeitnerAlgorithm
//
//  Created by Fatih Sağlam on 8.09.2024.
//

import Foundation

struct Word {
    let word: String
    let languageCode: String
    let meaning: String
    let exampleSentence: String?
    
    init(
        word: String,
        languageCode: String,
        meaning: String,
        exampleSentence: String?
    ) {
        self.word = word
        self.languageCode = languageCode
        self.meaning = meaning
        self.exampleSentence = exampleSentence
    }
}
