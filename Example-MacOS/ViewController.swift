//
//  ViewController.swift
//  Example-MacOS
//
//  Created by Aaron Vegh on 2021-01-18.
//

import Cocoa
import ArgusSSHKit

class ViewController: NSViewController {

    @IBOutlet var serverField: NSTextField!
    @IBOutlet var usernameField: NSTextField!
    @IBOutlet var passwordField: NSTextField!
    @IBOutlet var portsField: NSTextField!
    @IBOutlet var outputView: NSTextView!
    
    var tunnelManager = TunnelManager()

    @IBAction func connect(sender: NSButton) {
        let ports = portsField.stringValue.components(separatedBy: ",").compactMap({ Int($0.trimmingCharacters(in: .whitespaces)) })
        for port in ports {
            let localPort = Int.random(in: 1025..<36000)
            outputView.textStorage?.append(NSAttributedString(string: "Opening \(localPort) -> \(port)\n"))
            let tunnel = tunnelManager.createTunnel(hostname: serverField.stringValue, username: usernameField.stringValue, password: passwordField.stringValue, localPort: localPort, remotePort: port, delegate: self)
            do {
                try tunnel.start()
            } catch(let error) {
                print("Error connecting: \(error)")
            }
        }
    }

    @IBAction func disconnect(sender: NSButton) {
        tunnelManager.closeTunnels()
    }
}

extension ViewController: TunnelDelegateProtocol {
    func connectionOpened() {
        DispatchQueue.main.async {
            self.outputView.textStorage?.append(NSAttributedString(string: "Tunnels now open.\n"))
        }
    }
    
    func connectionClosed() {
        DispatchQueue.main.async {
            self.outputView.textStorage?.append(NSAttributedString(string: "Tunnels closed.\n"))
        }
    }
    
    func connectionError(error: TunnelError) {
        DispatchQueue.main.async {
            self.outputView.textStorage?.append(NSAttributedString(string: "Error: \(error)\n"))
        }
    }
    
    
}
