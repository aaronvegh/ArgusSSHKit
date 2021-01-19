//
//  ErrorHandler.swift
//  TunnelManager
//
//  Created by Stefan Arentz on 17/01/2021.
//


import Foundation

import NIO


final class ErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Any

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("Error in pipeline: \(error)")
        context.close(promise: nil)
    }
}
