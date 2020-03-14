//
//  Store.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Foundation
import Combine

enum Loadable<Done> {
    case done(Done)
    case loading
}

class SchoologyStore: ObservableObject {
    let client: SchoologyClient
    
    @Published var courses: Loadable<Result<[Course], Error>>?
    
    private var cancellables = Set<AnyCancellable>()
    private var courseMaterialsStores = [Int: CourseMaterialsStore]()
    
    func requestCourses(force: Bool = false) {
        if force || courses == nil {
            self.courses = .loading
            cancellables.insert(client.courses().sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    DispatchQueue.main.async {
                        self.courses = .done(.failure(error))
                    }
                }
            }, receiveValue: { courses in
                DispatchQueue.main.async {
                    self.courses = .done(.success(courses))
                }
            }))
        }
    }
    
    func courseMaterialsStore(for courseId: Int) -> CourseMaterialsStore {
        if courseMaterialsStores[courseId] == nil {
            courseMaterialsStores[courseId] = CourseMaterialsStore(client: client, courseId: courseId)
        }
        
        return courseMaterialsStores[courseId]!
    }
    
    init(client: SchoologyClient) {
        self.client = client
    }
}

class CourseMaterialsStore: ObservableObject {
    let client: SchoologyClient
    let courseId: Int
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var materials = [String?: Loadable<Result<[Material], Error>>]()
    
    init(client: SchoologyClient, courseId: Int) {
        self.client = client
        self.courseId = courseId
    }
    
    func requestFolder(id: String?, force: Bool = false) {
        if force || materials[id] == nil {
            materials[id] = .loading
            cancellables.insert(client.materials(courseId: courseId, folderId: id).sink(receiveCompletion: { completion in
                DispatchQueue.main.async {
                    if case .failure(let error) = completion {
                        self.materials[id] = .done(.failure(error))
                    }
                }
            }, receiveValue: { materials in
                DispatchQueue.main.async {
                    self.materials[id] = .done(.success(materials))
                }
            }))
        }
    }
}

extension CourseMaterialsStore {
    func materials(in folderId: String?) -> Result<[Material], Error>? {
        requestFolder(id: folderId)
        switch materials[folderId] {
        case .none, .some(.loading):
            return nil
        case .some(.done(let result)):
            return result
        }
    }
}
