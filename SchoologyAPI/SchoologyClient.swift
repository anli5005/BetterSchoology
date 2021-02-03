//
//  SchoologyClient.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Foundation
import Combine
import SwiftSoup

let schoologyAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+?&"))

let dueDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(identifier: "America/New_York")
    formatter.locale = Locale(identifier: "en-US")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "EEEE, MMMM d, y 'at' h:mm a"
    formatter.defaultDate = Date()
    return formatter
}()

class SchoologyClient {
    let session: URLSession
    let prefix: String
    let schoolId: String
    var materialDetailFetchers: [MaterialDetailFetcher]
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    private let delegate: SessionDelegate
        
    init(sessionConfiguration: URLSessionConfiguration, prefix: String, schoolId: String, materialDetailFetchers: [MaterialDetailFetcher] = []) {
        delegate = SessionDelegate()
        self.session = URLSession(configuration: sessionConfiguration, delegate: delegate, delegateQueue: nil)
        self.prefix = prefix
        self.schoolId = schoolId
        self.materialDetailFetchers = materialDetailFetchers
        
        delegate.client = self
    }
    
    func authenticate(credentials: SchoologyCredentials) -> Future<Void, Error> {
        return Future<Void, Error> { promise in
            var request = URLRequest(url: URL(string: "\(self.prefix)/login/ldap?&school=\(self.schoolId)")!)
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "POST"
            
            guard
                let mail = credentials.username.addingPercentEncoding(withAllowedCharacters: schoologyAllowed),
                let pass = credentials.password.addingPercentEncoding(withAllowedCharacters: schoologyAllowed)
                else {
                    promise(.failure(SchoologyAuthenticationError.percentEncodingError))
                    return
            }
            
            let body = "mail=\(mail)&pass=\(pass)&school_nid=\(self.schoolId)&form_id=s_user_login_form"
            self.session.uploadTask(with: request, from: Data(body.utf8)) { (data, response, error) in
                if let error = error {
                    promise(.failure(error))
                } else if data.map({ String(data: $0, encoding: .utf8) })??.contains("Sorry, unrecognized username or password.") == false {
                    promise(.success(()))
                } else {
                    promise(.failure(SchoologyAuthenticationError.unrecognizedCredentials))
                }
            }.resume()
        }
    }
    
    func siteNavigationUiProps() -> Publishers.Decode<Publishers.TryMap<URLSession.DataTaskPublisher, Data>, SiteNavigationUiProps, JSONDecoder> {
        return session.dataTaskPublisher(for: URL(string: "\(prefix)/info")!).tryMap { result in
            guard let string = String(data: result.data, encoding: .utf8) else {
                throw SchoologyParseError.badEncoding
            }
            
            let document = try SwiftSoup.parse(string)
            guard let element = try document.select("#bottom-bar + script").first() else {
                throw SchoologyParseError.unexpectedHtmlError
            }
            
            let html = try element.html()
            guard let range = html.range(of: "window.siteNavigationUiProps=") else {
                throw SchoologyParseError.unexpectedHtmlError
            }
            return Data(html.suffix(from: range.upperBound).utf8)
        }.decode(type: SiteNavigationUiProps.self, decoder: decoder)
    }
    
    struct CoursesResponse: Decodable {
        var data: CoursesResponseData
        struct CoursesResponseData: Decodable {
            var courses: [Course]
        }
    }
            
    func courses() -> Publishers.Map<Publishers.Decode<Publishers.Map<URLSession.DataTaskPublisher, Data>, CoursesResponse, JSONDecoder>, [Course]> {
        return session
            .dataTaskPublisher(for: URL(string: "\(prefix)/iapi2/site-navigation/courses?includeAll=1")!)
            .map { $0.data }
            .decode(type: CoursesResponse.self, decoder: decoder)
            .map { $0.data.courses }
    }
    
    func materials(courseId: Int, folderId: String?) -> Publishers.TryMap<URLSession.DataTaskPublisher, [Material]> {
        var components = URLComponents(string: "\(prefix)/course/\(courseId)/materials")!
        if let f = folderId {
            components.queryItems = [URLQueryItem(name: "f", value: f)]
        }
        
        return session.dataTaskPublisher(for: components.url!)
            .tryMap { result in
                guard let string = String(data: result.data, encoding: .utf8) else {
                    throw SchoologyParseError.badEncoding
                }
                
                let document = try SwiftSoup.parse(string)
                let rows = try document.select("table#folder-contents-table > tbody > tr")
                
                if try rows.isEmpty() && document.select(".materials-top").isEmpty() {
                    throw SchoologyParseError.unexpectedHtmlError
                }
                
                return try rows.map { row in
                    let id = row.id()
                    guard let a = try row.select(".item-info a").first() else {
                        throw SchoologyParseError.unexpectedHtmlError
                    }
                    
                    let name: String
                    if let infotip = try row.select(".infotip").first() {
                        guard let textNode = try? infotip.textNodes().first ?? row.select(".infotip-content").first()?.textNodes().first else {
                            throw SchoologyParseError.unexpectedHtmlError
                        }
                        name = textNode.text()
                    } else {
                        name = try a.text()
                    }
                    
                    let kind: Material.Kind
                    let meta: Any?
                    if row.hasClass("material-row-folder") {
                        kind = .folder
                        meta = FolderMeta(description: try row.select(".folder-description").first()?.html(), iconClass: try row.select(".inline-icon").first()?.className())
                    } else if row.hasClass("type-document") {
                        let icon = try row.select(".inline-icon")
                        if icon.hasClass("link-icon") {
                            kind = .link
                            meta = nil
                        } else {
                            kind = .file
                            meta = try icon.first()?.className()
                        }
                    } else if row.hasClass("type-discussion") {
                        kind = .discussion
                        meta = nil
                    } else if row.hasClass("type-page") {
                        kind = .page
                        meta = nil
                    } else if row.hasClass("type-quiz") {
                        kind = .quiz
                        meta = nil
                    } else if row.hasClass("type-assignment") {
                        if try row.select(".assessment-icon").count > 0 {
                            kind = .quiz
                        } else {
                            kind = .assignment
                        }
                        meta = nil
                    } else {
                        kind = .other
                        meta = nil
                    }
                    
                    var due: Date?
                    if let text = try row.select(".item-subtitle > span").first()?.text(), text.starts(with: "Due ") {
                        due = dueDateFormatter.date(from: String(text.suffix(text.count - 4)))
                    }
                    
                    return Material(
                        id: String(id.suffix(from: id.index(id.startIndex, offsetBy: 2))),
                        name: try Entities.unescape(name),
                        kind: kind,
                        available: nil,
                        due: due,
                        meta: meta,
                        urlSuffix: try a.attr("href")
                    )
                }
            }
    }
    
    func detailFetcher(for material: Material) -> MaterialDetailFetcher? {
        materialDetailFetchers.first(where: { $0.canFetch(material: material) })
    }
    
    func fetchDetails(for material: Material) -> AnyPublisher<MaterialDetail, Error> {
        if let fetcher = detailFetcher(for: material) {
            return fetcher.fetch(material: material, using: self).map {
                precondition(type(of: $0) == fetcher.type(for: material))
                return $0
            }.eraseToAnyPublisher()
        } else {
            return Future { $0(.success(OtherMaterialDetail(material: material) as MaterialDetail)) }.eraseToAnyPublisher()
        }
    }
    
    struct LikeResponse: Codable {
        var c: Int
        var h: String
        
        var liked: Bool {
            h == "Unlike"
        }
    }
    
    func like(messageId: String, csrf: CSRFDetails? = nil) -> Publishers.Decode<Publishers.Map<URLSession.DataTaskPublisher, Data>, LikeResponse, JSONDecoder> {
        var request = URLRequest(url: URL(string: "\(prefix)/like/c/\(messageId)")!)
        request.httpMethod = "POST"
        csrf?.apply(to: &request)
        
        return session.dataTaskPublisher(for: request).map(\.data).decode(type: LikeResponse.self, decoder: decoder)
    }
    
    struct ReplyResponse: Codable {
        var status: Bool
        var ajax_submit_output: String
    }
    
    func reply(discussion detail: DiscussionMaterialDetail, parent: String?, content: String) -> Publishers.Decode<Publishers.Map<URLSession.DataTaskPublisher, Data>, ReplyResponse, JSONDecoder> {
        var request = URLRequest(url: URL(string: prefix + detail.material.urlSuffix)!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        
        let items = detail.replyQueryItems + [
            URLQueryItem(name: "pid", value: parent),
            URLQueryItem(name: "comment", value: content.zwjIfEmpty.escapingEmoji().addingPercentEncoding(withAllowedCharacters: schoologyAllowed)),
            URLQueryItem(name: "drupal_ajax", value: "1")
        ]
        var components = URLComponents()
        components.queryItems = items
        request.httpBody = components.query?.data(using: .utf8)
            
        return session.dataTaskPublisher(for: request).map { result in
            if let str = String(data: result.data, encoding: .utf8), let begin = str.firstIndex(of: "{"), let end = str.lastIndex(of: "}"), begin < end {
                return Data(str[begin...end].utf8)
            }
            
            return result.data
        }.decode(type: ReplyResponse.self, decoder: decoder)
    }
    
    struct UploadDetailsResponse: Codable {
        var content: String
        var js: Js
        struct Js: Codable {
            var setting: Setting
            struct Setting: Codable {
                var s_common: Common
                var s_attachment: Attachment
                
                struct Common: Codable {
                    var user: User
                    struct User: Codable {
                        var uid: String
                    }
                }
                
                struct Attachment: Codable {
                    var file_service_upload: FileServiceUpload
                    struct FileServiceUpload: Codable {
                        var token: String
                        var token_expire: Date
                    }
                }
            }
        }
    }
    
    func uploadDetails(for submissionAccepting: SubmissionAccepting) -> AnyPublisher<UploadDetailsResponse, Error> {
        var request = URLRequest(url: URL(string: prefix + submissionAccepting.submitURLSuffix!)!)
        request.httpMethod = "GET"
        request.addValue("json/popups", forHTTPHeaderField: "X-Drupal-Render-Mode")
        
        return session.dataTaskPublisher(for: request).map { result in result.data }.decode(type: UploadDetailsResponse.self, decoder: decoder).eraseToAnyPublisher()
    }
    
    struct UploadResponse: Codable {
        var fileMetadataId: String
    }
    
    var ongoingUploads = [Int: OngoingUpload]()
    class OngoingUpload {
        let task: URLSessionUploadTask
        let makeStream: ((InputStream?) -> Void) -> Void
        var data = Data()
        let success: (Data) -> Void
        let failure: (Error) -> Void
        
        init(task: URLSessionUploadTask, makeStream: @escaping ((InputStream?) -> Void) -> Void, success: @escaping (Data) -> Void, failure: @escaping (Error) -> Void) {
            self.task = task
            self.makeStream = makeStream
            self.success = success
            self.failure = failure
        }
    }
    
    func upload(name: String, type: String, token: String?, makeStream: @escaping ((InputStream?) -> Void) -> Void) -> AnyPublisher<String, Error> {
        Future<Data, Error> { promise in
            let boundary = generateMultipartBoundary()
            
            var request = URLRequest(url: URL(string: self.prefix + "/file/upload-service")!)
            request.httpMethod = "POST"
            request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            if let token = token {
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let prefix = """
            --\(boundary)
            Content-Disposition: form-data; name="name"
            
            \(name)\r
            --\(boundary)
            Content-Disposition: form-data; name="use_plain"
            
            1\r
            --\(boundary)
            Content-Disposition: form-data; name="file"; filename="\(name)"
            Content-Type: \(type)
            
            
            """.data(using: .utf8)!
            
            let suffix = "\r\n--\(boundary)--".data(using: .utf8)!
            
            let task = self.session.uploadTask(withStreamedRequest: request)
            let upload = OngoingUpload(task: task, makeStream: { completion in
                makeStream { stream in
                    if let stream = stream {
                        completion(SerialInputStream(inputStreams: [
                            InputStream(data: prefix),
                            stream,
                            InputStream(data: suffix)
                        ]))
                    } else {
                        completion(nil)
                    }
                }
            }, success: { data in
                promise(.success(data))
            }, failure: { error in
                promise(.failure(error))
            })
            self.ongoingUploads[task.taskIdentifier] = upload
            task.resume()
        }.decode(type: UploadResponse.self, decoder: decoder).map { $0.fileMetadataId }.eraseToAnyPublisher()
    }
    
    class SessionDelegate: NSObject, URLSessionDataDelegate {
        weak var client: SchoologyClient?
        
        func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
            if let upload = client?.ongoingUploads[task.taskIdentifier] {
                upload.makeStream(completionHandler)
            } else {
                completionHandler(nil)
            }
        }
        
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            if let upload = client?.ongoingUploads[dataTask.taskIdentifier] {
                upload.data += data
            }
        }
        
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let upload = client?.ongoingUploads[task.taskIdentifier] {
                if let error = error {
                    upload.failure(error)
                } else {
                    upload.success(upload.data)
                }
                client!.ongoingUploads[task.taskIdentifier] = nil
            }
        }
    }
    
    struct UploadRequest: Encodable {
        var title: String
        var encode = true
        
        init(_ title: String) {
            self.title = title
        }
    }
    
    func submit(fileMetadataIdsAndTitles: [String: String], with comment: String? = nil, to submissionAccepting: SubmissionAccepting, uploadDetails: UploadDetailsResponse) -> AnyPublisher<Void, Error> {
        let boundary = generateMultipartBoundary()
        
        var components = URLComponents(string: prefix + submissionAccepting.submitURLSuffix!)!
        components.queryItems = [URLQueryItem(name: "destination", value: "/done")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.addValue("json/popups", forHTTPHeaderField: "X-Drupal-Render-Mode")
        
        let parts: [(String, Data)]
        do {
            guard let form = try SwiftSoup.parse(uploadDetails.content).getElementById("s-drop-item-submit-upload-form") else {
                throw SchoologyParseError.unexpectedHtmlError
            }
            
            let formItems = try extractFormFields(from: form, names: ["sid", "op", "form_build_id", "form_token", "form_id", "form_origin_popups", "target_DOM_id"])
            parts = try formItems.map { ($0, Data($1.utf8)) } + [
                ("file[files]", encoder.encode(fileMetadataIdsAndTitles.mapValues { UploadRequest($0) })),
                ("file[recording]", Data()),
                ("drop_item_comment", comment?.data(using: .utf8) ?? Data())
            ]
        } catch let e {
            return Fail(error: e).eraseToAnyPublisher()
        }
        
        var data = Data()
        for (name, part) in parts {
            data += Data("""
            --\(boundary)
            Content-Disposition: form-data; name="\(name)"
            
            
            """.utf8)
            data += part
            data += Data("\r\n".utf8)
        }
        data += Data("--\(boundary)--".utf8)
        request.httpBody = data
        
        return session.dataTaskPublisher(for: request).tryMap { result in
            print("Got response")
            if result.response.url?.lastPathComponent != "done" {
                throw SchoologyParseError.unexpectedHtmlError
            }
        }.eraseToAnyPublisher()
    }
}

extension CSRFDetails {
    func apply(to request: inout URLRequest) {
        request.addValue(csrf_key, forHTTPHeaderField: "X-Csrf-Key")
        request.addValue(csrf_token, forHTTPHeaderField: "X-Csrf-Token")
    }
}

extension DiscussionMaterialDetail {
    var replyQueryItems: [URLQueryItem] {
        replyDetails?.map { pair in
            URLQueryItem(name: pair.key, value: pair.value)
        } ?? []
    }
}

extension SchoologyClient.ReplyResponse {
    func message(parent: String?) throws -> Message {
        guard let comment = try SwiftSoup.parse(ajax_submit_output).select(".comment").first() else {
            throw SchoologyParseError.unexpectedHtmlError
        }
        return try parseMessage(comment: comment, parent: parent)
    }
}

extension String {
    func escapingEmoji() -> String {
        var newString = ""
        forEach { char in
            if char.unicodeScalars.first?.properties.isEmojiPresentation == true {
                newString += char.unicodeScalars.map { "&#x\(String($0.value, radix: 16));" }.joined()
            } else {
                newString.append(char)
            }
        }
        return newString
    }
    
    var zwjIfEmpty: String {
        isEmpty ? "\u{200d}" : self
    }
}

extension SubmissionToken {
    init(_ response: SchoologyClient.UploadDetailsResponse) {
        let setting = response.js.setting
        self.init(token: setting.s_attachment.file_service_upload.token, userId: setting.s_common.user.uid, expires: setting.s_attachment.file_service_upload.token_expire)
    }
}

func generateMultipartBoundary() -> String {
    return "----BetterSchoologyFormBoundary\(Data((0..<18).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }).base64EncodedString())".replacingOccurrences(of: "/", with: "-")
}
