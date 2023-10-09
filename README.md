前言
1.目前伪装最好的两种协议，一个代表tcp协议（reality）的目前巅峰，一个新型UDP协议（hysteria2）的宠儿。
2.这次用的sing-box搭建（https://sing-box.sagernet.org/zh/），因为简单，之前一直用八合一，最大的问题就是各种伪装后，机器就只能拿来科学上网了，因为安装Nginx，搭建个网页啥的都很麻烦。
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
