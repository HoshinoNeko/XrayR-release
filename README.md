# XRayR
A Xray backend framework that can easily support many panels.

一个基于Xray的后端框架，支持V2ay,Trojan,Shadowsocks协议，极易扩展，支持多面板对接

Find the source code here: [HoshinoNeko/XrayR](https://github.com/HoshinoNeko/XrayR)

# 详细使用教程

[教程](https://HoshinoNeko.github.io/XrayR-doc/)

# 一键安装

### 标准版（默认，适合常规服务器）
```bash
bash <(curl -Ls https://raw.githubusercontent.com/HoshinoNeko/XrayR-release/master/install.sh)
```

### Minimal 版（适合小内存服务器）
通过指定参数 `minimal` 安装精简版，全程无需交互确认，完全支持无人值守安装：
```bash
bash <(curl -Ls https://raw.githubusercontent.com/HoshinoNeko/XrayR-release/master/install.sh) minimal
```

## 版本说明

从 `v0.9.6` 版本开始，XrayR 提供两个版本：

| 版本 | 说明 | 适用场景 | 证书支持 |
|------|------|--------|---------|
| **标准版 (Standard)** | 包含完整功能和全部 DNS 提供商支持 | 常规服务器、需要自动申请证书 | 支持 ACME 自动申请 (`dns`/`http`/`tls`) 及本地文件证书 (`file`) |
| **Minimal 版** | 精简版，去除了 lego 自动证书申请实现（去除大部分 DNS 提供商） | 小内存服务器、不需要自动申请证书 | 仅支持本地文件证书 (`CertMode: file`) 或无需证书 (`none`) |

> [!NOTE]
> Minimal 版本由于移除了 lego 库，显著减小了二进制体积及运行内存占用。Minimal 版本不支持自动申请证书，若节点需要 TLS，请使用外部工具（如 acme.sh / certbot）申请证书，并在配置中设置 `CertMode: file`。

### 安装命令参考

```bash
# 安装最新标准版（默认）
bash <(curl -Ls https://raw.githubusercontent.com/HoshinoNeko/XrayR-release/master/install.sh)

# 安装最新 Minimal 版
bash <(curl -Ls https://raw.githubusercontent.com/HoshinoNeko/XrayR-release/master/install.sh) minimal

# 安装指定版本的标准版
bash <(curl -Ls https://raw.githubusercontent.com/HoshinoNeko/XrayR-release/master/install.sh) v0.9.6

# 安装指定版本的 Minimal 版（Minimal 自 v0.9.6 开始提供）
bash <(curl -Ls https://raw.githubusercontent.com/HoshinoNeko/XrayR-release/master/install.sh) v0.9.6 minimal
```

### 更新 XrayR

```bash
# 更新到最新版本（自动保持当前已安装的版本类型：标准版或 Minimal 版）
XrayR update

# 更新到指定版本（保持当前版本类型）
XrayR update v0.9.6

# 更新/切换到最新 Minimal 版
XrayR update minimal

# 更新/切换到指定 Minimal 版
XrayR update v0.9.6 minimal

# 切换回最新标准版
XrayR update standard
```

# Docker 安装

### 标准版
```bash
docker pull ghcr.io/HoshinoNeko/xrayr:latest && docker run --restart=always --name xrayr -d -v ${PATH_TO_CONFIG}/config.yml:/etc/XrayR/config.yml --network=host ghcr.io/HoshinoNeko/xrayr:latest
```

### Minimal 版
```bash
docker pull ghcr.io/HoshinoNeko/xrayr:latest-minimal && docker run --restart=always --name xrayr -d -v ${PATH_TO_CONFIG}/config.yml:/etc/XrayR/config.yml --network=host ghcr.io/HoshinoNeko/xrayr:latest-minimal
```

# Docker compose 安装
0. 安装docker-compose: 
```bash
curl -fsSL https://get.docker.com | bash -s docker
curl -L "https://github.com/docker/compose/releases/download/1.26.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```
1. `git clone https://github.com/HoshinoNeko/XrayR-release`
2. `cd XrayR-release`
3. 编辑config。
配置文件基本格式如下，Nodes下可以同时添加多个面板，多个节点配置信息，只需添加相同格式的Nodes item即可。
4. 启动docker：`docker-compose up -d`
```yaml
Log:
  Level: none # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json Path to dns config
ConnetionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 10 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB 
Nodes:
  -
    PanelType: "SSpanel" # Panel type: SSpanel, V2board, PMpanel
    ApiConfig:
      ApiHost: "http://127.0.0.1:667"
      ApiKey: "123"
      NodeID: 41
      NodeType: V2ray # Node type: V2ray, Shadowsocks, Trojan
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: 0 # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: 0 # Local settings will replace remote settings, 0 means disable
      RuleListPath: # /etc/XrayR/rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/fallback/ for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: dns # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "node1.test.com" # Domain to cert
        CertFile: /etc/XrayR/cert/node1.test.com.cert # Provided if the CertMode is file
        KeyFile: /etc/XrayR/cert/node1.test.com.key
        Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          ALICLOUD_ACCESS_KEY: aaa
          ALICLOUD_SECRET_KEY: bbb
  # -
  #   PanelType: "V2board" # Panel type: SSpanel, V2board
  #   ApiConfig:
  #     ApiHost: "http://127.0.0.1:668"
  #     ApiKey: "123"
  #     NodeID: 4
  #     NodeType: Shadowsocks # Node type: V2ray, Shadowsocks, Trojan
  #     Timeout: 30 # Timeout for the api request
  #     EnableVless: false # Enable Vless for V2ray Type
  #     EnableXTLS: false # Enable XTLS for V2ray and Trojan
  #     SpeedLimit: 0 # Mbps, Local settings will replace remote settings
  #     DeviceLimit: 0 # Local settings will replace remote settings
  #   ControllerConfig:
  #     ListenIP: 0.0.0.0 # IP address you want to listen
  #     UpdatePeriodic: 10 # Time to update the nodeinfo, how many sec.
  #     EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
  #     CertConfig:
  #       CertMode: dns # Option about how to get certificate: none, file, http, dns
  #       CertDomain: "node1.test.com" # Domain to cert
  #       CertFile: /etc/XrayR/cert/node1.test.com.cert # Provided if the CertMode is file
  #       KeyFile: /etc/XrayR/cert/node1.test.com.pem
  #       Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
  #       Email: test@me.com
  #       DNSEnv: # DNS ENV option used by DNS provider
  #         ALICLOUD_ACCESS_KEY: aaa
  #         ALICLOUD_SECRET_KEY: bbb
```

## Docker compose升级
在docker-compose.yml目录下执行：
```bash
docker-compose pull
docker-compose up -d
```
