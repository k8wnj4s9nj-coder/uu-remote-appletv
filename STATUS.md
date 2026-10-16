# Status

## Done this run
- ConnectOptions protobuf encoder
- Socket.IO binary `be-controlled` emit
- UUWebRTCMediaSession: offer/answer/ICE + data channels + remote track callback
- RemoteVideoView (LKRTCVideoView / RTCMTLVideoView)
- LiveKit SPM wired in xcodeproj + Protocol/Package.swift
- scripts/add-webrtc-on-mac.sh, fetch-livekit-webrtc.sh
- README / NOTES updated

## Blocking real pixels today
- Must build on Mac with LiveKit package resolved (tvOS 17+)
- Possible protocol/ICE fine-tuning against live host logs
- uuremote-server left running (do not kill)
