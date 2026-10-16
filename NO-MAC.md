# 不用本机 Mac：GitHub Actions 编译 + atvloadly 侧载

## 结论（GitHub 现成方案）

| 步骤 | 工具 | 要不要本机 Mac |
|---|---|---|
| 编译 tvOS IPA | [GitHub Actions `macos-14`](https://github.com/features/actions) 跑本仓库 `.github/workflows/build-tvos-ipa.yml` | **不要** |
| 装到 Apple TV | [bitxeno/atvloadly](https://github.com/bitxeno/atvloadly)（Linux Docker） | **不要 Mac**，但机器必须和 Apple TV **同一局域网** |

Linux **不能**交叉编译官方 tvOS SDK；“免 Mac”= 用云端 macos runner，不是本机 Linux 硬编。

## 1. 推仓库并触发编译

```bash
# 在已登录 gh 的机器上
gh repo create uu-remote-appletv --public --source=. --remote=origin --push
gh workflow run build-tvos-ipa.yml
gh run watch
gh run download -n UURemoteTV-unsigned-ipa
```

得到 `UURemoteTV-unsigned.ipa`。

## 2. 侧载（家用 Linux / NAS）

1. 装 `avahi-daemon`，`docker compose -f docker-compose.atvloadly.yml up -d`
2. 浏览器打开 `http://<家用机器IP>:5533`
3. Apple TV：设置 → 遥控器与设备 → 遥控器 App 与设备 → 进入配对
4. atvloadly 里配对 → 上传 IPA → Install（用 Apple ID 签名，免费账号约 7 天需刷新）

**注意：** 云电脑一般发现不了你家的 Apple TV（Bonjour 不过公网）。atvloadly 请装在家里和电视同网的设备上。

## 参考仓库

- https://github.com/bitxeno/atvloadly
- https://github.com/schultzyyy271/ATVLoader （Windows 侧载，同样要同网 + 证书）
