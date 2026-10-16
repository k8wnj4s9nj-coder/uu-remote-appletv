# UU 远程 · Apple TV（非官方）

> **Unofficial / 非官方**：与网易无关。界面与文档均标注非官方。请使用你自己的账号。

目标：Apple TV (tvOS) 上的 UU 远程**控制端**，**只看画面**（键鼠后续再说）。

路径：`/workspace/uu-remote-appletv/`。

## 当前能力（诚实）

| 能力 | 状态 |
|---|---|
| 扫码登录 | ✅ |
| 设备列表 `GET /api/v1/device/list` | ✅（现网验证过） |
| 入房 `POST /api/v1/room/join/by_device/{id}` | ✅ |
| Socket.IO 信令 + `room_info` | ✅ |
| `be-controlled` + ConnectOptions protobuf | ✅（按主机侧字段编码） |
| SOAC offer / answer / candidate | ✅（源码路径完整） |
| WebRTC PeerConnection + 远端 video track → UI | ✅ 源码已接；**需 Mac 解析 LiveKit SPM** |
| 真机出画 | ⚠️ **必须在 Mac 用 Xcode 编一次**（本 Linux 盒无 tvOS/WebRTC 二进制链接） |
| 键鼠 | ❌ |

## WebRTC 依赖（Mac 必做）

工程已写入 SPM：

- 仓库：https://github.com/livekit/webrtc-xcframework  
- 产品：`LiveKitWebRTC`（符号前缀 `LK`，如 `LKRTCPeerConnection`）  
- **含 tvOS 17 device + simulator**（见该仓库 README）

```bash
# 在 Mac 上打开工程后一般会自动 Resolve；也可：
./scripts/add-webrtc-on-mac.sh
# 可选离线下载 zip：
./scripts/fetch-livekit-webrtc.sh
```

Xcode：打开 `AppleTV/UURemoteTV.xcodeproj` → 等 Package resolve → Signing 选你的 Team → 选 Apple TV（**tvOS 17+**）→ Run。

若 `canImport(LiveKitWebRTC)` 为 false，会话页会提示「WebRTC 未链接」，只跑信令 stub。

备选：System73 的 `WebRTCtvOS` SPM（仅 tvOS）。主路径用 LiveKit。

## 目录

```
uu-remote-appletv/
  README.md
  NOTES-PROTOCOL.md
  STATUS.md
  Protocol/Sources/UURemoteProtocol/   # 含 ConnectOptions / Signaling / WebRTCMediaSession
  AppleTV/UURemoteTV.xcodeproj
  AppleTV/UURemoteTV/                  # SwiftUI + RemoteVideoView
  scripts/add-webrtc-on-mac.sh
  scripts/fetch-livekit-webrtc.sh
  _research/                           # 协议参考（含 uu-remote-linux 克隆）
```

## Mac 安装到 Apple TV

1. 拷贝本目录到 Mac。  
2. Xcode 15+，打开 `AppleTV/UURemoteTV.xcodeproj`。  
3. Resolve `livekit/webrtc-xcframework`。  
4. Signing → Automatic → 你的 Apple ID / Team；Bundle ID `com.unofficial.uuremote.tv` 可改。  
5. 部署到 Apple TV 17+ 或模拟器。  
6. 手机 UU App 扫码登录 → 设备列表 → 连接观看。

## 连接时序（控制端）

1. `join/by_device` → signaling URL + token  
2. WebSocket Engine.IO / Socket.IO，`X-NRD-AUTH`  
3. `room_info` ack  
4. 二进制 `be-controlled`（ConnectOptions：capture_type=1 + H264 decoder cap）  
5. 本地 `createOffer`（video/audio recvOnly + CONTROL/TEXT/FILE/BINARY data channels）  
6. SOAC `offer`（带同一 `ice_id` / `client_id`）  
7. 收 SOAC `answer` + `candidate`；发本地 candidate  
8. 远端 `LKRTCVideoTrack` → `LKRTCVideoView`

与本机 `uuremote-server`（不要停）对拍时，主机日志应出现 be-controlled → offer → answer。

## 仍可能挡住出画的点

1. Mac 未 Resolve LiveKit 包 → 无帧，只有状态字。  
2. ConnectOptions / `be-controlled` 头字段与官方仍有细微差异 → 主机忽略会话（看 `uuremote-server` 日志）。  
3. ICE 失败（复杂 NAT）→ 云侧 TURN 未注入；当前用公共 STUN，与主机无 iceServers 时回退一致。  
4. 官方 SDP 扩展 / gzip_sdp：主机支持；我们发明文 SDP。  
5. LiveKit 小版本符号若与胶水不完全一致，可能需在 Mac 上改一两个类型名（见 `WebRTCMediaSession.swift`）。

## 法律

勿冒充官方；勿提交 token / config.json。
