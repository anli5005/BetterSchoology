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
    @Published var overdueMaterials: Loadable<Result<[UpcomingMaterial], Error>>?
    @Published var upcomingMaterials: Loadable<Result<[UpcomingMaterial], Error>>?
    
    @Published var materialDetails = [String: Loadable<Result<MaterialDetail, Error>>]()
    var materialDetailsPublishers = [String: AnyPublisher<MaterialDetail, Error>]()
    
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
    
    func requestOverdueMaterials(force: Bool = false) {
        if force || overdueMaterials == nil {
            self.overdueMaterials = .loading
            client.overdueMaterials().sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    DispatchQueue.main.async {
                        self.overdueMaterials = .done(.failure(error))
                    }
                }
            }, receiveValue: { materials in
                let now = Date()
                let overdue = materials.filter { $0.material.due! <= now } // Sometimes Schoology returns non-overdue stuff
                DispatchQueue.main.async {
                    self.overdueMaterials = .done(.success(overdue.sorted(by: { $0.material.due! < $1.material.due! })))
                }
            }).store(in: &cancellables)
        }
    }
    
    func requestUpcomingMaterials(force: Bool = false) {
        if force || upcomingMaterials == nil {
            self.upcomingMaterials = .loading
            client.upcomingMaterials().sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    DispatchQueue.main.async {
                        self.upcomingMaterials = .done(.failure(error))
                    }
                }
            }, receiveValue: { materials in
                DispatchQueue.main.async {
                    self.upcomingMaterials = .done(.success(materials.sorted(by: { $0.material.due! < $1.material.due! })))
                }
            }).store(in: &cancellables)
        }
    }
    
    func courseMaterialsStore(for courseId: Int) -> CourseMaterialsStore {
        if courseMaterialsStores[courseId] == nil {
            courseMaterialsStores[courseId] = CourseMaterialsStore(client: client, courseId: courseId)
        }
        
        return courseMaterialsStores[courseId]!
    }
    
    func requestMaterialDetails(material: Material, force: Bool = false) {
        if force || materialDetails[material.id] == nil {
            let publisher = client.fetchDetails(for: material)
            
            cancellables.insert(publisher.sink(receiveCompletion: { completion in
                DispatchQueue.main.async {
                    if case .failure(let error) = completion {
                        self.materialDetails[material.id] = .done(.failure(error))
                        self.materialDetailsPublishers[material.id] = nil
                    }
                }
            }, receiveValue: { detail in
                DispatchQueue.main.async {
                    self.materialDetails[material.id] = .done(.success(detail))
                    self.materialDetailsPublishers[material.id] = nil
                }
            }))
            
            self.materialDetailsPublishers[material.id] = publisher
        }
        
        if materialDetails[material.id] == nil {
            materialDetails[material.id] = .loading
        }
    }
    
    init(client: SchoologyClient) {
        self.client = client
    }
}

class CourseMaterialsStore: ObservableObject {
    let client: SchoologyClient
    let courseId: Int
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published var materials = [String?: Loadable<Result<[Material], Error>>]()
    var materialsById = [String: Material]()
    let reloadPublisher = PassthroughSubject<Void, Never>()
    
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
                    for material in materials {
                        self.materialsById[material.id] = material
                    }
                    
                    var newMaterials = self.materials
                    newMaterials[id] = .done(.success(materials))
                    self.materials = newMaterials
                    
                    self.reloadPublisher.send()
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
