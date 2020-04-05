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
}

struct SchoologyFile {
    var name: String?
    var url: URL?
    var size: String?
    var iconClass: String?
    var typeDescription: String?
    
    var id: String? {
        url?.lastPathComponent
    }
}

struct FileMaterialDetail: MaterialDetail {
    var material: Material
    var fullName: String
    var file: SchoologyFile
}

struct AssignmentMaterialDetail: MaterialDetail {
    var material: Material
    var fullName: String
    var content: String
    var files: [SchoologyFile]
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
