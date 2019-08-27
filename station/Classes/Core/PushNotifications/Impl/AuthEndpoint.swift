//
//  AuthEndpoint.swift
//  iWallet
//
//  Created by Rinat Enikeev on 8/27/19.
//  Copyright © 2019 Suffescom. All rights reserved.
//

import Alamofire
import SwiftyJSON

struct AuthCredentials {
    var access: String
    var refresh: String
}

class AuthEndpoint {
    var context = ApiContext.shared
    
    private let path = "auth/"
    
    func login(email: String, password: String, completion: @escaping (Swift.Result<AuthCredentials,Error>) -> Void) {
        if let url = URL(string: context.baseUrl + path + "session") {
            var params = Dictionary<String, String>()
            params["email"] = email
            params["password"] = password
            context
                .sessionManager
                .request(url, method: .post, parameters: params)
                .validate()
                .responseJSON { (response) in
                    switch response.result {
                    case .success(let value):
                        let json = JSON(value)
                        if let access = json["access"].string,
                            let refresh = json["refresh"].string {
                            let credentials = AuthCredentials(access: access, refresh: refresh)
                            completion(.success(credentials))
                        } else {
                            completion(.failure(iWalletError.invalidResponse))
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
            }
        } else {
            completion(.failure(iWalletError.failedToParseUrl))
        }
    }
}
