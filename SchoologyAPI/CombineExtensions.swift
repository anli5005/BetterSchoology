//
//  CombineExtensions.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Foundation
import Combine

extension Publisher where Output == Data {
    func decoded<T: Decodable>(
        as type: T.Type = T.self,
        using decoder: JSONDecoder = .init()
    ) -> Publishers.TryMap<Self, T> {
        return tryMap { try decoder.decode(type, from: $0) }
    }
}
