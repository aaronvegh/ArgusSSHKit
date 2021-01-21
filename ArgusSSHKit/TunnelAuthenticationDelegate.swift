//
//  TunnelAuthenticationDelegate.swift
//  TunnelManager
//
//  Created by Stefan Arentz on 17/01/2021.
//


import Foundation

import NIO
import NIOSSH

public enum SSHAuthenticationType {
    case password
    case publicKey
}

public class SSHAuthenticationMethod: NSObject {
    let authType: SSHAuthenticationType
    let username: String
    
    let password: String?
    let publicKeyFile: String?
    let publicKeyPassword: String?
    
    public init(authType: SSHAuthenticationType, username: String, password: String?, publicKeyFile: String?, publicKeyPassword: String?) {
        self.authType = authType
        self.username = username
        self.password = password
        self.publicKeyFile = publicKeyFile
        self.publicKeyPassword = publicKeyPassword
        super.init()
    }
}

final class TunnelAuthenticationDelegate: NIOSSHClientUserAuthenticationDelegate {
    private var authentication: SSHAuthenticationMethod
    
    private var attemptedPassword: Bool = false
    private var attemptedPrivateKey: Bool = false

    init(authentication: SSHAuthenticationMethod) {
        self.authentication = authentication
    }

    func nextAuthenticationType(availableMethods: NIOSSHAvailableUserAuthenticationMethods, nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>) {
        guard availableMethods.contains(.password) else {
            nextChallengePromise.fail(TunnelError.passwordAuthenticationNotSupported)
            return
        }
        
        switch authentication.authType {
        case .password:
            guard let password = authentication.password else { nextChallengePromise.fail(TunnelError.authenticationFailed)
                return
            }
            let offer = NIOSSHUserAuthenticationOffer(username: self.authentication.username, serviceName: "", offer: .password(.init(password: password)))
            nextChallengePromise.succeed(offer)
            return
        case .publicKey:
            // TODO: figure out how to handle private keys.
            // SwiftNIO doesn't handle OpenSSH keys?!
            break
        }
    
        nextChallengePromise.fail(TunnelError.authenticationFailed)
    }
}
