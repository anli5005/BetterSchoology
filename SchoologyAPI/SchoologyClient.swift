//
//  SchoologyClient.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Foundation
import Combine

class SchoologyClient {
    let session: URLSession
    let prefix: String
    let schoolId: String
        
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
}
