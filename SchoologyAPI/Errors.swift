//
//  Errors.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

enum SchoologyAuthenticationError: Error {
    case percentEncodingError
    case unrecognizedCredentials
}

enum SchoologyParseError: Error {
    case badEncoding
    case unexpectedHtmlError
    case badUrl
    case badStatusCode
}
