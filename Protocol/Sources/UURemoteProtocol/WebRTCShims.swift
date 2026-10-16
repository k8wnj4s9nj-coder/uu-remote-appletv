import Foundation

#if canImport(LiveKitWebRTC)
import LiveKitWebRTC
public typealias UUVideoRendererView = LKRTCMTLVideoView
public let uuWebRTCLinked = true
#elseif canImport(WebRTC)
import WebRTC
#if os(tvOS) || os(iOS)
public typealias UUVideoRendererView = RTCMTLVideoView
#else
public typealias UUVideoRendererView = RTCMTLNSVideoView
#endif
public let uuWebRTCLinked = true
#else
public let uuWebRTCLinked = false
#endif
