//
//  LeitnerError.swift
//
//
//  Created by Fatih Sağlam on 29.09.2024.
//

import Foundation

public enum LeitnerError: Error, Equatable {
    case cardNotFound
    case reviewProcessError(reason: String?)
}
