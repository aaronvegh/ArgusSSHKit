//
//  TunnelError.swift
//  TunnelManager
//
//  Created by Stefan Arentz on 17/01/2021.
//


import Foundation


public enum TunnelError: Error {
    case passwordAuthenticationNotSupported
    case privateKeyAuthenticationNotSupported
    case commandExecFailed
    case invalidChannelType
    case invalidData
    case authenticationFailed
}
