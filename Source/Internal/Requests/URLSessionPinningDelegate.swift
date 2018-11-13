//
//  URLSessionPinningDelegate.swift
//  Webtrekk
//
//  Created by Martin Demiddel on 14.08.18.
//  Copyright © 2018 Webtrekk. All rights reserved.
//

import Foundation

class URLSessionPinningDelegate: NSObject, URLSessionDelegate {
    var certificates: [Data] = CertificateHandler.getPinning()

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
        if let serverTrust = challenge.protectionSpace.serverTrust, SecTrustGetCertificateCount(serverTrust) > 0 {

            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) {
                let data = SecCertificateCopyData(certificate) as Data

                if certificates.contains(data) {
                    completionHandler(.useCredential, URLCredential(trust: serverTrust))

                    return
                }
            }
        }
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
