# UU 远程协议笔记（非官方 · 无密钥）

## 控制端媒体路径（本仓库实现）

```
join/by_device → Socket.IO connect → room_info
  → emit binary be-controlled + ConnectOptions
  → createOffer (recv video/audio + data channels)
  → SOAC offer (ice_id 对齐)
  → SOAC answer / candidates
  → remote video track
```

### ConnectOptions（protobuf）

主机 `signaling.rs` 解码约定：

| field | 含义 |
|---|---|
| 1 | capture_type（≤2 为桌面） |
| 4 | repeated DecoderCap |

DecoderCap：`1=fps, 2=codec(1 H264,2 H265), 3=w, 4=h, 5=chroma(1=420)`  

实现：`ConnectOptions.swift` → `UUConnectOptions.encode()`.

### be-controlled 头（JSON）+ 1 个二进制附件

Socket.IO：`451-["be-controlled", header, {_placeholder:true,num:0}]` + binary frame。

头字段（主机读取）：`ice_id`/`iceId`, `client_id`, `app_control_id`, `controller_platform`（5=tv）, `streamer_data`（含 control_id）, 可选 `iceServers` / `force_relay`。

### SOAC

- 控制端发 `offer` / `candidate`；主机回 `answer` / `candidate`。  
- 包装：`{ "client_id", "data": SoacMessage }`。  
- 主机在 answer 前已 `add_track` 视频；viewer offer 应带 Opus + video。

### DataChannel 标签（主机 on_data_channel）

`CONTROL_DATA_CHANNEL`, `TEXT_DATA_CHANNEL`, `FILE_DATA_CHANNEL`, `BINARY_DATA_CHANNEL`（控制端在 offer 里创建；本里程碑不发键鼠）。

### ICE

- 主机：`SessionIce::from_header`；无服务器时回退公共 STUN。  
- 控制端当前同样使用公共 STUN；若官方客户端会下发 TURN，后续可把 iceServers 填进 be-controlled 头。

## REST（摘要）

- Base `https://api.nrd.nie.163.com`  
- HMAC-SHA256：`METHOD + path + sorted(x-param-*) + body` → `X-Param-SIGN`  
- 登录 QR：`/api/v1/qrcode/gen/login` → status → `/api/v1/login/by_qrcode`  
- 设备列表：`GET /api/v1/device/list`  
- 入房：`POST /api/v1/room/join/by_device/{device_id}`  

## WebRTC 二进制

- **主选**：LiveKit `webrtc-xcframework`（tvOS 17+）模块 `LiveKitWebRTC`  
- 备选：System73 `WebRTCtvOS`  
- Linux 无法链接；`#if canImport(LiveKitWebRTC)` 回退 stub。

## 下一步逆向（若真机无画）

1. 对照主机日志：be-controlled 是否到达、capture_type、offer ice_id 是否匹配。  
2. 抓官方 Mac/手机控制端一份 be-controlled 头字段集合（脱敏）。  
3. 确认是否必须带云 TURN（`emptyICEServersResult` 字符串存在于官方客户端）。  
4. 若 LiveKit 符号编译失败，按报错把 `LKRTC*` 对齐到已下载的 headers。
