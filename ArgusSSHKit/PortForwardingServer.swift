//
//  PortForwardingServer.swift
//  TunnelManager
//
//  Created by Stefan Arentz on 17/01/2021.
//


import Foundation

import NIO
import NIOSSH


final class PortForwardingServer {
    private var serverChannel: Channel?
    private let serverLoop: EventLoop
    private let group: EventLoopGroup
    private let bindHost: String
    private let bindPort: Int
    private let forwardingChannelConstructor: (Channel) -> EventLoopFuture<Void>
    var delegate: TunnelDelegateProtocol

    init(delegate: TunnelDelegateProtocol, group: EventLoopGroup, bindHost: String, bindPort: Int, _ forwardingChannelConstructor: @escaping (Channel) -> EventLoopFuture<Void>) {
        self.delegate = delegate
        self.serverLoop = group.next()
        self.group = group
        self.forwardingChannelConstructor = forwardingChannelConstructor
        self.bindHost = bindHost
        self.bindPort = bindPort
    }

    func run() -> EventLoopFuture<Void> {
        let server = ServerBootstrap(group: self.serverLoop, childGroup: self.group)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer(self.forwardingChannelConstructor)
            .bind(host: self.bindHost, port: self.bindPort)
        server.whenFailure { error in
            print("Error: \(error)")
        }
        server.whenSuccess { channel in
            print("Success!")
        }
        return server.flatMap { channel -> EventLoopFuture<Void> in
            self.delegate.connectionOpened()
            self.serverChannel = channel
            return channel.closeFuture
        }
//            .flatMapError({ error -> EventLoopFuture<Channel> in
//                print("Error: \(error)")
//                return error as! EventLoopFuture<Channel>
//            })
//            .flatMap {
//                self.delegate.connectionOpened()
//                self.serverChannel = $0
//                return $0.closeFuture
//            }
    }

    func close() -> EventLoopFuture<Void> {
        self.serverLoop.flatSubmit {
            guard let server = self.serverChannel else {
                // The server wasn't created yet, so we can just shut down straight away and let
                // the OS clean us up.
                return self.serverLoop.makeSucceededFuture(())
            }
            self.delegate.connectionClosed()
            return server.close()
        }
    }
}
