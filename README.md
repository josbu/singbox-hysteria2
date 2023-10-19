```markdown
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

### 如何需要卸载

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

# singbox-hysteria2

## 端口跳跃

```bash
apt install iptables-persistent
iptables -F
iptables -X
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p udp --dport 8443 -j ACCEPT
iptables -A INPUT -p udp --dport 20000:40000 -j ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -L
iptables -t nat -A PREROUTING -p udp --dport 20000:40000 -j DNAT --to-destination :8443
iptables -t nat -nL --line
netfilter-persistent save
```
```

这是一个格式化后的Markdown文本，你可以复制粘贴到你的GitHub项目的`README.md`文件中。
