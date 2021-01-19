//
//  TunnelAuthenticationDelegate.swift
//  TunnelManager
//
//  Created by Stefan Arentz on 17/01/2021.
//


import Foundation

import NIO
import NIOSSH


final class TunnelAuthenticationDelegate: NIOSSHClientUserAuthenticationDelegate {
    private var username: String
    private var password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    func nextAuthenticationType(availableMethods: NIOSSHAvailableUserAuthenticationMethods, nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>) {
        guard availableMethods.contains(.password) else {
            nextChallengePromise.fail(TunnelError.passwordAuthenticationNotSupported)
            return
        }

        let offer = NIOSSHUserAuthenticationOffer(username: self.username, serviceName: "", offer: .password(.init(password: self.password)))
        nextChallengePromise.succeed(offer)
    }
}
