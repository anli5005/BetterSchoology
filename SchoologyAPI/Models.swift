//
//  Models.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Foundation

struct Course: Codable, Identifiable {
    var nid: Int
    var courseTitle: String
    var sectionTitle: String
    var buildingTitle: String
    var logoImgSrc: String
    var courseNid: Int
    var weight: Int
    var isCsl: Bool
    var adminType: String
    
    var id: Int { nid }
}

struct SiteNavigationUiProps: Decodable {
    var props: Props
    
    struct Props: Decodable {
        var user: User
    }
}

struct User: Codable, Identifiable {
    var language: String
    var languageNameNative: String
    var logoutToken: String
    var uid: Int
    var name: String
    var profilePictureUrl: String
    
    var id: Int { uid }
}

struct Material: Identifiable {
    var id: String
    var name: String
    var kind: Kind
    var available: Date?
    var due: Date?
    var dueTime: Bool?
    var meta: Any?
    var urlSuffix: String
    
    enum Kind {
        case file
        case folder
        case assignment
        case quiz
        case page
        case link
        case discussion
        case other
    }
}

struct FolderMeta {
    var description: String?
    var iconClass: String?
}

protocol MaterialDetail {
    var material: Material { get }
    var fullName: String { get }
}

struct LinkMaterialDetail: MaterialDetail {
    var material: Material
    var fullName: String
    var url: URL?
}

struct PageMaterialDetail: MaterialDetail {
    var material: Material
    var fullName: String
    var content: String
    var files: [SchoologyFile]
}

struct SchoologyFile {
    var name: String?
    var url: URL?
    var size: String?
    var iconClass: String?
    var typeDescription: String?
    var isDownload: Bool
    
    var id: String? {
        guard let components = url?.pathComponents else {
            return nil
        }
        
        if components.starts(with: ["/", "attachment"]) && components.last == "source" {
            return components[components.count - 2]
        }
                
        return url?.absoluteString
    }
}

struct FileMaterialDetail: MaterialDetail {
    var material: Material
    var fullName: String
    var file: SchoologyFile
}

protocol SubmissionAccepting {
    var submitURLSuffix: String? { get }
}

extension SubmissionAccepting {
    var acceptsSubmissions: Bool { submitURLSuffix != nil }
}

protocol SubmissionStatusProviding {
    var isSubmitted: Bool { get }
}

protocol SubmissionStatusAssignable: SubmissionStatusProviding {
    var isSubmitted: Bool { get set }
}

struct AssignmentMaterialDetail: MaterialDetail, SubmissionAccepting, SubmissionStatusAssignable {
    var material: Material
    var fullName: String
    var content: String
    var files: [SchoologyFile]
    var submitURLSuffix: String?
    var isSubmitted: Bool
}

struct QuizMaterialDetail: MaterialDetail {
    var material: Material
    var fullName: String { material.name }
}

struct Message: Identifiable {
    var id: String
    
    var parent: String?
    var children: [String]
    
    var date: Date?
    var authorName: String
    var content: String
    var likes: Int
    var liked: Bool
    var isAdmin: Bool
    
    var replies: Int { children.count }
}

struct DiscussionMaterialDetail: MaterialDetail {
    var material: Material
    var fullName: String
    var content: String
    var files: [SchoologyFile]
    var messages: [String: Message]
    var rootMessages: [String]
    var csrf: CSRFDetails?
    var replyDetails: [String: String]?
}

struct FolderMaterialDetail: MaterialDetail {
    var material: Material
    var fullName: String
    var description: String?
}

struct OtherMaterialDetail: MaterialDetail {
    var material: Material
    var fullName: String { material.name }
}

struct CSRFDetails: Codable {
    var csrf_key: String
    var csrf_token: String
}

struct DrupalSettings: Decodable {
    var s_common: CSRFDetails
}

struct SubmissionToken {
    var token: String
    var userId: String
    var expires: Date
    
    func isExpired(asOf date: Date = Date()) -> Bool {
        return date >= expires
    }
}

