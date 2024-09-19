//
//  Word.swift
//  LeitnerAlgorithm
//
//  Created by Fatih Sağlam on 8.09.2024.
//

import Foundation

public struct Word {
    public let word: String
    public let languageCode: String
    public let meaning: String
    public let exampleSentence: String?
    
    public init(
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
