//
//  certificateHandler.swift
//  Webtrekk
//
//  Created by Martin Demiddel on 22.08.18.
//  Copyright © 2018 Webtrekk. All rights reserved.
//

import Foundation

internal class CertificateHandler {
    /** Set pinning here, this will use URLSessionPinningDelegate iso the default URLSessionDelegate
     which will check for the given certificate to be included in your application with the certificate on the server **/
    internal static var hasPinning: Bool = false
    private static var certificateCollection: [Data] = []

    /**
     This internal handle is necessary for the cross platform ability to work with the pinning.
     If we use the WebtrekkTracking, then we have to rely on all the other structures to be available and
     test all of these. Which is an indefinite labor. Hence the use of this handler which is an internal use
     for both and abstraction for the outside usage of pinning.

     ### Usage Example ###
     ```
     CertificateHandler.setPinning(certificates: [Data])
     ```
     * Sets the `Boolean` variable `hasPinning`
     * Sets the `Array` variable `certificateCollection`
     
     - Parameter certificates: Array of certificates
     */
    internal static func setPinning(certificates: [Data]) {
        if certificates.isEmpty {
            self.hasPinning = false
            return
        }

        self.hasPinning = true
        certificateCollection = certificates
    }

    /**
     Used in URLSessionPinningDelegate to get the pinning Certificates.
     
     ### Usage Example ###
     ```
     CertificateHandler.getPinning()
     ```
     - Returns: certificateCollection: Array collection of certificates
    */
    internal static func getPinning() -> [Data] {
        return certificateCollection
    }
}
