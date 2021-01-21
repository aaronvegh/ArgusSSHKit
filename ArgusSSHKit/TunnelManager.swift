//
//  TunnelManager.swift
//  TunnelManager
//
//  Created by Stefan Arentz on 17/01/2021.
//


import Foundation

import NIO
import NIOSSH


public class Tunnel: NSObject {
    let group: EventLoopGroup
    
    let hostname: String
    let username: String
    let password: String
    
    let localPort: Int
    let remotePort: Int
    
    var server: PortForwardingServer?
    var channel: Channel?
    var delegate: TunnelDelegateProtocol
    
    init(group: EventLoopGroup, hostname: String, username: String, password: String, localPort: Int, remotePort: Int, delegate: TunnelDelegateProtocol) {
        self.group = group
        self.hostname = hostname
        self.username = username
        self.password = password
        
        self.localPort = localPort
        self.remotePort = remotePort
        
        self.delegate = delegate
    }
    
    public func start() {
        do {
            self.channel = try connect().wait()
            let _ = forward()
        } catch (let error) {
            self.delegate.connectionError(error: error as! TunnelError)
        }
    }
    
    func connect() -> EventLoopFuture<Channel> {
        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { [self] channel in
                let userAuthDelegate = TunnelAuthenticationDelegate(username: username, password: password, privateKeyFile: nil, privateKeyPassword: nil)
                let serverAuthDelegate = AcceptAllHostKeysDelegate()
                return channel.pipeline.addHandlers([NIOSSHHandler(role: .client(.init(userAuthDelegate: userAuthDelegate, serverAuthDelegate: serverAuthDelegate)), allocator: channel.allocator, inboundChildChannelInitializer: nil), DebugInboundEventsHandler(), DebugOutboundEventsHandler(), ErrorHandler()])
            }
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)
        
        let channel = bootstrap.connect(host: hostname, port: 22)
        channel.whenFailure { error in
            print("Error setting up channel: \(error)")
        }
        return channel
    }
    
    func forward() -> EventLoopFuture<Void> {
        self.server = PortForwardingServer(delegate: delegate, group: group, bindHost: "127.0.0.1", bindPort: localPort) { [self] inboundChannel in
            channel!.pipeline.handler(type: NIOSSHHandler.self).flatMap { sshHandler in
                let promise = inboundChannel.eventLoop.makePromise(of: Channel.self)

                let directTCPIP = SSHChannelType.DirectTCPIP(targetHost: "127.0.0.1", targetPort: remotePort, originatorAddress: inboundChannel.remoteAddress!)
                sshHandler.createChannel(promise, channelType: .directTCPIP(directTCPIP)) { childChannel, channelType in
                    guard case .directTCPIP = channelType else {
                        return self.channel!.eventLoop.makeFailedFuture(TunnelError.invalidChannelType)
                    }
                    
                    let (ours, theirs) = GlueHandler.matchedPair()
                    return childChannel.pipeline.addHandlers([SSHWrapperHandler(), ours, ErrorHandler()]).flatMap {
                        inboundChannel.pipeline.addHandlers([theirs, ErrorHandler()])
                    }
                }
                return promise.futureResult.map { _ in }
            }
        }
        
        return server!.run()
    }

    public func stop() -> EventLoopFuture<Void> {
        return self.server!.close()
    }
}


public class TunnelManager: NSObject {
    var tunnels: [Int: Tunnel] = [:]
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let delegate: TunnelDelegateProtocol? = nil

    public func createTunnel(hostname: String, username: String, password: String, localPort: Int, remotePort: Int, delegate: TunnelDelegateProtocol) -> Tunnel {
        let tunnel = Tunnel(group: self.group, hostname: hostname, username: username, password: password, localPort: localPort, remotePort: remotePort, delegate: delegate)
        tunnels[remotePort] = tunnel
        return tunnel
    }
    
    public func closeTunnels() {
        for key in tunnels.keys {
            let tunnel = tunnels[key]
            _ = tunnel?.server?.close()
        }
    }
}
