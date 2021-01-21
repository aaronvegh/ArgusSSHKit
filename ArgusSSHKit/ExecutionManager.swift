//
//  ExecutionManager.swift
//  ArgusSSHKit
//
//  Created by Aaron Vegh on 2021-01-19.
//

import Foundation
import NIO
import NIOSSH

public class Execution: NSObject {
    let group: EventLoopGroup
    
    let hostname: String
    let authentication: SSHAuthenticationMethod
    
    let command: String
    
    var server: PortForwardingServer?
    var channel: Channel?
    
    public init(group: EventLoopGroup, hostname: String, authentication: SSHAuthenticationMethod, command: String) {
        self.group = group
        self.hostname = hostname
        self.authentication = authentication
        
        self.command = command
    }
    
    public func start(command: String) {
        do {
            self.channel = try connect().wait()
            let _ = execute(command: command)
        } catch (let error) {
            print("Starting error: \(error)")
//            self.delegate.connectionError(error: error as! TunnelError)
        }
    }
    
    func connect() -> EventLoopFuture<Channel> {
        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { [self] channel in
                let userAuthDelegate = TunnelAuthenticationDelegate(authentication: authentication)
                let serverAuthDelegate = AcceptAllHostKeysDelegate()
                return channel.pipeline.addHandlers([NIOSSHHandler(role: .client(.init(userAuthDelegate: userAuthDelegate, serverAuthDelegate: serverAuthDelegate)), allocator: channel.allocator, inboundChildChannelInitializer: nil), ErrorHandler()])
            }
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)

        let channel = bootstrap.connect(host: hostname, port: 22)
        channel.whenFailure { error in
            print("Error setting up channel: \(error)")
        }
        return channel
    }
    
    public func execute(command: String) {
        do {
            guard let channel = self.channel else { return }
            let exitStatusPromise = channel.eventLoop.makePromise(of: Int.self)
            let childChannel: Channel = try channel.pipeline.handler(type: NIOSSHHandler.self).flatMap { sshHandler in
                    let promise = channel.eventLoop.makePromise(of: Channel.self)
                    sshHandler.createChannel(promise) { childChannel, channelType in
                        guard channelType == .session else {
                            return channel.eventLoop.makeFailedFuture(SSHClientError.invalidChannelType)
                        }
                        return childChannel.pipeline.addHandlers([ExampleExecHandler(command: command, completePromise: exitStatusPromise), ErrorHandler()])
                    }
                    return promise.futureResult
                }.wait()

                // Wait for the connection to close
                try childChannel.closeFuture.wait()
                let exitStatus = try exitStatusPromise.futureResult.wait()
                try channel.close().wait()
        } catch (let error) {
            print("Error: \(error)")
        }
    }
    
}

public class ExecutionManager: NSObject {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    
    public func createExecution(hostname: String, authentication: SSHAuthenticationMethod, command: String) -> Execution {
        let exec = Execution(group: group, hostname: hostname, authentication: authentication, command: command)
        return exec
    }
}
