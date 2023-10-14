前言
1.目前伪装最好的两种协议，一个代表tcp协议（reality）的目前巅峰，一个新型UDP协议（hysteria2）的宠儿。
2.这次用的sing-box搭建（https://sing-box.sagernet.org/zh/）
3.教程亮点，无需自备域名。
4.passwall发现没有类似的设置教程，所以出一个。

安装sing-box
正式版 （支持hysteria2）

bash -c "$(curl -L https://raw.githubusercontent.com/josbu/singbox-hysteria2/main/hysteria2.sh)" @ install
直接安装预发布版（支持hysteria2）

bash -c "$(curl -L https://sing-box.vercel.app)" @ install --beta
如何需要卸载

bash -c "$(curl -L https://sing-box.vercel.app)" @ remove
等会用得到的指令
重启

systemctl restart sing-box
状态

systemctl status sing-box
实时日志

journalctl -u sing-box -o cat -f
服务端vps搭建
自签证书申请，这里申请的是bing.com，申请了10年，可以用到你vps商家跑路了# singbox-hysteria2

端口跳跃
# Debian&&Ubuntu

## 安装iptables-persistent
apt install iptables-persistent

## 清空默认规则
iptables -F

## 清空自定义规则
iptables -X

## 允许本地访问
iptables -A INPUT -i lo -j ACCEPT

## 开放SSH端口（假设SSH端口为22）
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

## 开放HTTP端口
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

## 开放UDP端口（10010替换为节点的监听端口）
iptables -A INPUT -p udp --dport 10010 -j ACCEPT

## 开放UDP端口范围（假设UDP端口范围为20000-40000）
iptables -A INPUT -p udp --dport 20000:40000 -j ACCEPT

## 允许接受本机请求之后的返回数据
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

## 其他入站一律禁止
iptables -P INPUT DROP

## 允许所有出站
iptables -P OUTPUT ACCEPT

## 查看开放的端口
iptables -L

## 添加NAT规则，20000:40000替换为你设置端口跳跃的范围，8443替换为你节点的监听端口
iptables -t nat -A PREROUTING -p udp --dport 20000:40000 -j DNAT --to-destination :8443

## 查看NAT规则
iptables -t nat -nL --line

## 保存iptables规则
netfilter-persistent save
