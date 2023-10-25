# 前言

1. 目前伪装最好的两种协议，一个代表tcp协议（reality）的目前巅峰，一个新型UDP协议（hysteria2）的宠儿。
2. 这次用的sing-box搭建（[https://sing-box.sagernet.org/zh/](https://sing-box.sagernet.org/zh/)）
3. 教程亮点，无需自备域名。
4. passwall发现没有类似的设置教程，所以出一个。

## 安装sing-box

### 正式版 （支持hysteria2）

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/josbu/singbox-hysteria2/main/hysteria2.sh)" @ install
```

### 直接安装预发布版（支持hysteria2）

```bash
bash -c "$(curl -L https://sing-box.vercel.app)" @ install --beta
```

### 如果需要卸载

```bash
bash -c "$(curl -L https://sing-box.vercel.app)" @ remove
```

## 等会用得到的指令

- 重启

```bash
systemctl restart sing-box
```

- 状态

```bash
systemctl status sing-box
```

- 实时日志

```bash
journalctl -u sing-box -o cat -f
```

## 服务端vps搭建

- 自签证书申请，这里申请的是bing.com，申请了10年，可以用到你vps商家跑路了
```bash
mkdir -p /etc/hysteria && openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/private.key && openssl req -new -x509 -days 3650 -key /etc/hysteria/private.key -out /etc/hysteria/cert.pem -subj "/CN=bing.com"
```

```markdown
# 搭建组合选择

参考网站 [https://github.com/chika0801/sing-box-examples](https://github.com/chika0801/sing-box-examples)。后期可以根据需求自由组合。

## 为什么选择 reality 和 hysteria2

1. reality 目前是TCP协议里面号称最安全的。
2. hysteria2 作者是最用心的，教程写得很清楚（[https://v2.hysteria.network/zh/](https://v2.hysteria.network/zh/)）。

## 开始

### 编辑 config 文件

```bash
nano /usr/local/etc/sing-box/config.json
```

按照以下修改：

```json
{
    "inbounds": [
        {
            "type": "hysteria2",
            "listen": "::",
            "listen_port": 8444,
            "users": [
                {
                    "password": "" // 你的密码
                }
            ],
            "masquerade": "https://bing.com",
            "tls": {
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "/etc/hysteria/cert.pem",
                "key_path": "/etc/hysteria/private.key"
            }
        },
        {
            "type": "vless",
            "listen": "::",
            "listen_port": 443,
            "users": [
                {
                    "uuid": "", // vps上执行 sing-box generate uuid
                    "flow": "xtls-rprx-vision"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "www.tesla.com",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "www.tesla.com",
                        "server_port": 443
                    },
                    "private_key": "", // vps上执行 sing-box generate reality-keypair
                    "short_id": [
                        "0123456789abcdef" // 0到f，长度为2的倍数，长度上限为16，默认这个也可以
                    ]
                }
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct"
        }
    ]
}
```

### 重启 sing-box

```bash
systemctl restart sing-box
```

### 查看日志

```bash
journalctl -u sing-box -o cat -f
```


## 端口跳跃

```bash
apt install iptables-persistent
iptables -t nat -A PREROUTING -p udp --dport 38000:40000 -j DNAT --to-destination :8444
ip6tables -t nat -A PREROUTING -p udp --dport 38000:40000 -j DNAT --to-destination :8444
netfilter-persistent save
```

