//
//  Store.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Foundation
import Combine

class SchoologyStore: ObservableObject {
    let client: SchoologyClient
    
    @Published var courses: Result<[Course], Error>? = nil
    
    private var cancellables: Set<AnyCancellable> = []
    
    func requestCourses(force: Bool = false) {
        if force || courses == nil {
            cancellables.insert(client.courses().sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    DispatchQueue.main.async {
                        self.courses = .failure(error)
                    }
                }
            }, receiveValue: { courses in
                DispatchQueue.main.async {
                    self.courses = .success(courses)
                }
            }))
        }
    }
    
    init(client: SchoologyClient) {
        self.client = client
    }
}
