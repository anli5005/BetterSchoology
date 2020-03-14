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

class SchoologyClient {
    let session: URLSession
    let prefix: String
    let schoolId: String
    let decoder = JSONDecoder()
        
    init(session: URLSession, prefix: String, schoolId: String) {
        self.session = session
        self.prefix = prefix
        self.schoolId = schoolId
    }
    
    func authenticate(credentials: SchoologyCredentials) -> Future<Void, Error> {
        return Future<Void, Error> { promise in
            var request = URLRequest(url: URL(string: "\(self.prefix)/login/ldap?&school=\(self.schoolId)")!)
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "POST"
            
            guard
                let mail = credentials.username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                let pass = credentials.password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
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
}
