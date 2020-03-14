//
//  AuthView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI
import Combine

private extension Error {
    var authDescription: String {
        switch self {
        case let self as SchoologyAuthenticationError:
            switch self {
            case .unrecognizedCredentials:
                return "Unrecognized username or password."
            case .percentEncodingError:
                return "Credentials could not be percent-encoded."
            }
        default:
            return "Sorry, an error occurred."
        }
    }
}

struct AuthView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var client: SchoologyClient
    
    @State var username = ""
    @State var password = ""
    @State var signingIn: AnyCancellable?
    @State var error: Error?
    
    var valid: Bool {
        !username.isEmpty && !password.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Welcome to")
            Text("BetterSchoology").font(.title).fontWeight(.bold)
            Text("Please enter your Schoology credentials.").padding(.vertical)
            error.map { Text($0.authDescription).fontWeight(.bold).foregroundColor(.red) }
            Group {
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
            }.disabled(signingIn != nil)
            if signingIn == nil {
                Button("Sign In", action: {
                    print("Signing in with username \(self.username)")
                    let credentials = SchoologyCredentials(username: self.username, password: self.password)
                    self.signingIn = self.client.authenticate(credentials: credentials).sink(receiveCompletion: { completion in
                        switch completion {
                        case .failure(let error):
                            print("Sign in error.")
                            DispatchQueue.main.async {
                                self.error = error
                                self.signingIn = nil
                            }
                        case .finished:
                            print("Sign in complete.")
                        }
                    }, receiveValue: { value in
                        print("Sign in successful!")
                        DispatchQueue.main.async {
                            self.signingIn = self.client.siteNavigationUiProps().sink(receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    self.error = error
                                    self.signingIn = nil
                                }
                            }, receiveValue: { props in
                                DispatchQueue.main.async {
                                    self.authContext.status = .authenticated(user: props.props.user, store: SchoologyStore(client: self.client))
                                }
                            })
                        }
                    })
                    self.error = nil
                })
            } else {
                Button("Signing in...", action: {}).disabled(true)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView().frame(width: 400).padding()
    }
}
