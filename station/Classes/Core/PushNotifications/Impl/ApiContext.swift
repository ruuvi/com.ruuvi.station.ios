//
//  ApiContext.swift
//  iWallet
//
//  Created by Rinat Enikeev on 8/27/19.
//  Copyright © 2019 Suffescom. All rights reserved.
//

import Foundation
import Alamofire

class ApiContext {
    static let shared = ApiContext()
    let baseUrl = "https://staging.iwallet.com/api/v1/app/"
    var sessionManager: SessionManager
    
    init() {
        let serverTrustPolicies: [String: ServerTrustPolicy] = [
            "staging.iwallet.com": .pinPublicKeys(
                publicKeys: ServerTrustPolicy.publicKeys(),
                validateCertificateChain: true,
                validateHost: true
            )
        ]
        let configuration = URLSessionConfiguration.default
        var headers = SessionManager.defaultHTTPHeaders
        headers["Content-Type"] = "application/json"
        configuration.httpAdditionalHeaders = headers
        self.sessionManager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(
                policies: serverTrustPolicies
            )
        )
    }
}
