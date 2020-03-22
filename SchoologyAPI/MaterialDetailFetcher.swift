//
//  MaterialDetailFetcher.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/15/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Combine
import Foundation
import SwiftSoup

let messageDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(identifier: "America/New_York")
    formatter.locale = Locale(identifier: "en-US")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "E MMM d, y 'at' h:mm a"
    return formatter
}()

extension Material {
    func urlPublisher(prefix: String) -> Future<URL, Error> {
        Future { promise in
            if let url = URL(string: prefix + self.urlSuffix) {
                promise(.success(url))
            } else {
                promise(.failure(SchoologyParseError.badUrl))
            }
        }
    }
}

extension Publisher {
    func castingToError() -> Publishers.MapError<Self, Error> {
        return mapError { $0 as Error }
    }
}

extension Publisher where Output == URLSession.DataTaskPublisher.Output {
    func toString(encoding: String.Encoding) -> Publishers.TryMap<Self, String> {
        return tryMap {
            guard let string = String(data: $0.data, encoding: encoding) else {
                throw SchoologyParseError.badEncoding
            }
            
            return string
        }
    }
}

protocol MaterialDetailFetcher {
    func canFetch(material: Material) -> Bool
    func type(for material: Material) -> MaterialDetail.Type?
    func fetch(material: Material, using client: SchoologyClient) -> AnyPublisher<MaterialDetail, Error>
}

extension MaterialDetailFetcher {
    func canFetch(material: Material) -> Bool {
        return type(for: material) != nil
    }
}

func extractLinkURL(from string: String) -> URL? {
    if let path = URLComponents(string: string)?.queryItems?.first(where: { $0.name == "path" })?.value {
        return URL(string: path)
    } else {
        return nil
    }
}

struct SimpleLinkFetcher: MaterialDetailFetcher {
    func type(for material: Material) -> MaterialDetail.Type? {
        return (material.kind == .link && material.urlSuffix.starts(with: "/link")) ? LinkMaterialDetail.self : nil
    }
    
    func fetch(material: Material, using client: SchoologyClient) -> AnyPublisher<MaterialDetail, Error> {
        return AnyPublisher(Future { promise in
            promise(.success(LinkMaterialDetail(material: material, fullName: material.name, url: extractLinkURL(from: material.urlSuffix)) as MaterialDetail))
        })
    }
}

struct PageLinkFetcher: MaterialDetailFetcher {
    func type(for material: Material) -> MaterialDetail.Type? {
        return (material.kind == .link && material.urlSuffix.starts(with: "/course")) ? LinkMaterialDetail.self : nil
    }
    
    func fetch(material: Material, using client: SchoologyClient) -> AnyPublisher<MaterialDetail, Error> {
        return AnyPublisher(material.urlPublisher(prefix: client.prefix).flatMap { client.session.dataTaskPublisher(for: $0).castingToError() }.toString(encoding: .utf8).tryMap { str in
            guard let a = try SwiftSoup.parse(str).select("h2.page-title a").first() else {
                throw SchoologyParseError.unexpectedHtmlError
            }
            
            var url: URL?
            if let href = try? a.attr("href") {
                url = extractLinkURL(from: href)
            }
            
            return LinkMaterialDetail(material: material, fullName: try a.text(), url: url) as MaterialDetail
        })
    }
}

struct PageFetcher: MaterialDetailFetcher {
    func type(for material: Material) -> MaterialDetail.Type? {
        return material.kind == .page ? PageMaterialDetail.self : nil
    }
    
    func fetch(material: Material, using client: SchoologyClient) -> AnyPublisher<MaterialDetail, Error> {
        return material.urlPublisher(prefix: client.prefix).flatMap { client.session.dataTaskPublisher(for: $0).castingToError() }.toString(encoding: .utf8).tryMap { str in
            let document = try SwiftSoup.parse(str)
            return PageMaterialDetail(
                material: material,
                fullName: try document.select(".s-page-title").text(),
                content: try document.select(".s-page-content-full").html()
            ) as MaterialDetail
        }.eraseToAnyPublisher()
    }
}

func extractFile(from attachment: Element) throws -> SchoologyFile {
    let icon = try attachment.select(".inline-icon")
    let a = try attachment.select(".attachments-file-name > a").not(".view-file-popup")
    return SchoologyFile(
        name: try attachment.select(".infotip").first()?.textNodes().first?.text() ?? a.text(),
        url: URL(string: try a.attr("href")),
        size: try attachment.select(".attachments-file-size").first()?.text(),
        iconClass: try icon.first()?.className(),
        typeDescription: try icon.select(".visually-hidden").first()?.text()
    )
}

struct FileFetcher: MaterialDetailFetcher {
    func type(for material: Material) -> MaterialDetail.Type? {
        return material.kind == .file ? FileMaterialDetail.self : nil
    }
    
    func fetch(material: Material, using client: SchoologyClient) -> AnyPublisher<MaterialDetail, Error> {
        return material.urlPublisher(prefix: client.prefix).flatMap { client.session.dataTaskPublisher(for: $0).castingToError() }.toString(encoding: .utf8).tryMap { str in
            let document = try SwiftSoup.parse(str)
            let fullName = try document.select(".page-title").text()
            let contentWrapper = try document.select("#content-wrapper")
            
            if let attachment = try contentWrapper.select(".attachments-file").first() {
                return FileMaterialDetail(
                    material: material,
                    fullName: fullName,
                    file: try extractFile(from: attachment)
                )
            } else {
                return FileMaterialDetail(
                    material: material,
                    fullName: fullName,
                    file: SchoologyFile(
                        name: fullName,
                        url: URL(string: try contentWrapper.select("img").attr("src")),
                        size: nil,
                        iconClass: nil,
                        typeDescription: nil
                    )
                )
            }
        }.eraseToAnyPublisher()
    }
}

struct AssignmentFetcher: MaterialDetailFetcher {
    func type(for material: Material) -> MaterialDetail.Type? {
        return material.kind == .assignment ? AssignmentMaterialDetail.self : nil
    }
    
    func fetch(material: Material, using client: SchoologyClient) -> AnyPublisher<MaterialDetail, Error> {
        return material.urlPublisher(prefix: client.prefix).flatMap { client.session.dataTaskPublisher(for: $0).castingToError() }.toString(encoding: .utf8).tryMap { str in
            let document = try SwiftSoup.parse(str)
            return AssignmentMaterialDetail(
                material: material,
                fullName: try document.select(".page-title").text(),
                content: try document.select(".info-body").html(),
                files: try document.select(".attachments-file").map { try extractFile(from: $0) }
            )
        }.eraseToAnyPublisher()
    }
}

func parseMessage(comment: Element, parent: String?) throws -> Message {
    var content = ""
    if let body = try comment.select(".comment-body-wrapper").first() {
        try body.select(".hidden, .comment-more-toggle").forEach { child in
            try body.removeChild(child)
        }
        content = try body.html()
    }
    
    return Message(
        id: comment.id().replacingOccurrences(of: "comment-", with: ""),
        parent: parent,
        children: [],
        date: messageDateFormatter.date(from: try comment.select(".comment-time span").text()),
        authorName: try comment.select(".comment-author a").text(),
        content: content,
        likes: Int(try comment.select(".s-like-comment-icon").text()) ?? 0,
        liked: try comment.select(".like-btn .content").text().contains("Un"),
        isAdmin: try comment.select(".comment_picture").hasClass("is-admin")
    )
}

func parseMessageTree(in root: Element) throws -> ([String: Message], [String]) {
    var result = [String: Message]()
    var toExplore = [(String, Element)]()
    
    let rootElements = root.children().filter { $0.hasClass("discussion-card") }.map { $0.children() }
    let rootMessages = try rootElements.map { children -> Message in
        guard let comment = children.first() else {
            throw SchoologyParseError.unexpectedHtmlError
        }
        
        return try parseMessage(comment: comment, parent: nil)
    }
    
    for (children, message) in zip(rootElements, rootMessages) {
        result[message.id] = message
        if let level = children.last(where: { $0.hasClass("s_comments_level") }) {
            toExplore.append((message.id, level))
        }
    }
    
    while !toExplore.isEmpty {
        let (parent, level) = toExplore.removeLast()
        var children = [String]()
        for child in level.children() {
            if child.hasClass("comment") {
                let message = try parseMessage(comment: child, parent: parent)
                result[message.id] = message
                children.append(message.id)
            } else if child.hasClass("s_comments_level") {
                if let id = children.last {
                    toExplore.append((id, child))
                } else {
                    throw SchoologyParseError.unexpectedHtmlError
                }
            }
        }
        result[parent]!.children = children
    }
    
    return (result, rootMessages.map { $0.id })
}

struct DiscussionFetcher: MaterialDetailFetcher {
    func type(for material: Material) -> MaterialDetail.Type? {
        return material.kind == .discussion ? DiscussionMaterialDetail.self : nil
    }
    
    func fetch(material: Material, using client: SchoologyClient) -> AnyPublisher<MaterialDetail, Error> {
        return material.urlPublisher(prefix: client.prefix).flatMap { client.session.dataTaskPublisher(for: $0).castingToError() }.toString(encoding: .utf8).tryMap { str in
            let document = try SwiftSoup.parse(str)
            var messages = [String: Message]()
            var rootMessages = [String]()
            if let comments = try document.select("#s_comments > .s_comments_level").first() {
                (messages, rootMessages) = try parseMessageTree(in: comments)
            }
            return DiscussionMaterialDetail(
                material: material,
                fullName: try document.select(".page-title").text(),
                content: try document.select(".discussion-prompt").html(),
                files: try document.select(".discussion-attachments .attachments-file").map { try extractFile(from: $0) },
                messages: messages,
                rootMessages: rootMessages
            )
        }.eraseToAnyPublisher()
    }
}
