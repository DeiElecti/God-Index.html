import Foundation
import MultipeerConnectivity

/// Handles discovery and messaging between two devices using MultipeerConnectivity.
final class PeerSessionManager: NSObject {
    private let serviceType = "dualcam-rec"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    override init() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    /// Start advertising to nearby peers.
    func startHosting() {
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    /// Start browsing for a host.
    func joinSession() {
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func send(data: Data) throws {
        if !session.connectedPeers.isEmpty {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
    }
}

extension PeerSessionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            onConnect?()
        case .notConnected:
            onDisconnect?()
        default:
            break
        }
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        onData?(data)
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension PeerSessionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension PeerSessionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

extension PeerSessionManager {
    /// Closure executed when data arrives from the peer.
    var onData: ((Data) -> Void)? {
        get { onDataBox.value }
        set { onDataBox.value = newValue }
    }

    /// Called when a peer connection is established.
    var onConnect: (() -> Void)? {
        get { onConnectBox.value }
        set { onConnectBox.value = newValue }
    }

    /// Called when the peer disconnects.
    var onDisconnect: (() -> Void)? {
        get { onDisconnectBox.value }
        set { onDisconnectBox.value = newValue }
    }

    private let onDataBox = CallbackBox<Data>()
    private let onConnectBox = CallbackBox<Void>()
    private let onDisconnectBox = CallbackBox<Void>()
}

/// Helper to allow simple stored property for closure in extensions.
final class CallbackBox<T> {
    var value: ((T) -> Void)?
}
