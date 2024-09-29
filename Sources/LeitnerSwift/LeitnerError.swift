//
//  LeitnerError.swift
//
//
//  Created by Fatih Sağlam on 29.09.2024.
//

import Foundation

enum LeitnerError: Error {
    case cardNotFound
    case reviewProcessError(reason: String?)
}
