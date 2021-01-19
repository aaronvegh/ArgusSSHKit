//
//  TunnelDelegate.swift
//  ArgusSSHKit
//
//  Created by Aaron Vegh on 2021-01-19.
//

import Foundation

public protocol TunnelDelegateProtocol {
    func connectionOpened()
    func connectionClosed()
    func connectionError(error: TunnelError)
}
