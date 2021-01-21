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
    private var password: String?
    private var privateKeyFile: String?
    private var privateKeyPassword: String?
    
    private var attemptedPassword: Bool = false
    private var attemptedPrivateKey: Bool = false

    init(username: String, password: String?, privateKeyFile: String?, privateKeyPassword: String?) {
        self.username = username
        self.password = password
        self.privateKeyFile = privateKeyFile
        self.privateKeyPassword = privateKeyPassword
    }

    func nextAuthenticationType(availableMethods: NIOSSHAvailableUserAuthenticationMethods, nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>) {
        guard availableMethods.contains(.password) else {
            nextChallengePromise.fail(TunnelError.passwordAuthenticationNotSupported)
            return
        }
        
        if let privateKeyFile = self.privateKeyFile, !attemptedPrivateKey {
            // TODO: figure out how to handle private keys.
            // SwiftNIO doesn't handle OpenSSH keys?!
            attemptedPrivateKey = true
            print("Has \(privateKeyFile)")
            nextChallengePromise.fail(TunnelError.privateKeyAuthenticationNotSupported)
        }
        
        if let password = self.password, !attemptedPassword {
            attemptedPassword = true
            let offer = NIOSSHUserAuthenticationOffer(username: self.username, serviceName: "", offer: .password(.init(password: password)))
            nextChallengePromise.succeed(offer)
        }
        
        nextChallengePromise.fail(TunnelError.authenticationFailed)
    }
}
