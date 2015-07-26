# gp_control
使用命令行来控制shadowsocks的多用户

###环境要求：
* 理论上只要linux操作系统，本人使用centos作为环境测试
* 启用iptables服务，Centos7使用的是firewall，需要关闭firewall，启用iptables防火墙
* 安装tcl环境
* 使用libev版本的shadowsocks作为服务端

###主要脚本及文件介绍<br>
gp_demo.tcl会创建4个线程：
* 定时关闭服务（gp.conf文件中设置定时关闭时间）
* shadowsocks服务状态监控线程（默认5分钟检查一次）
* 流量更新线程（gp.conf文件中设置更新间隔）
* 用户包月线程，检查用户是否过期、未过期且为月初则初始化流量

gp_c.tcl主要用途：
* 创建新用户
* 创建测试用户
* 增加用户购买月
* 修改shadowsocks帐号信息(修改端口、密码等)
* 手动删除一个用户
* 列出所有用户流量、到期信息

gp.conf文件参数列表：
```
#设置默认包月用户流量大小，单位G
m_flow=20
#设置ss服务重启时间，即，每天xx时间重启所有shadowsocks服务
c_time=04:00
#设置流量刷新间隔，单位秒
u_time=300
#设置是否发送提醒邮件，默认只能使用mutt作为发送客户端
send_mail=0
#设置默认加密方式
d_method=rc4-md5
#设置默认ss_server程序位置，如未设置，则会使用find命令自动查找
ss_server=/usr/local/shadowsocks/bin/ss-server
#设置服务端口范围
ss_port=30600-40000
#设置保存pid文件位置
piddir=/tmp/flow_user
#设置默认数据库文件名称，数据库存放在脚本目录下
db_file=geekproxy.db
```

###脚本运行

1. 创建目录，把下载多所有tcl文件放置到目录中

  >mkdir gp_control

2. 赋予执行权限

  chmod +x gp_demo.tcl  
  chmod +x gp_c.tcl
  其他脚本无需赋予权限，但需要放置在同一目录下

3. 执行gp_demo.tcl脚本，开启后台服务

  第一次后台运行：
  >nohup ./gp_demo.tcl >/dev/null 2>&1&

  下次开机自动运行：
  在/etc/rc.d/rc.local中写入开机运行
  运行后会在当前目录下创建一个geekproxy.db的sqlite类型的数据库文件，可以直接用sqlit命令查看相关信息。

4. gp_c.tcl的使用<br>
+-------------------Create a new user---------------------+<br>
./gp_c.tcl -a email_addr passwd     [method]    buy_month  <br>
**method**可以忽略不填，此时使用gp.conf文件指定的默认加密方式<br>
+-------------------Create a test user--------------------+<br>
./gp_c.tcl -t email_addr <br>
NOTICE：测试帐号默认2天过期，且测试流量为2G，密码随机生成<br>
+-------------------Buy more month------------------------+<br>
./gp_c.tcl -c email_addr buy_month  <br>
给指定用户购买更多流量<br>
+-------------------Change ss info------------------------+<br>
./gp_c.tcl -a email_addr [-P Passwd] [-p port]  [-m method]<br>
修改指定用户的密码、端口或加密方式，每次只能修改一个<br>
+-------------------Delete a user-------------------------+<br>
./gp_c.tcl -d email_addr<br>
手动删除指定用户<br>
+-------------------List all user info--------------------+<br>
./gp_c.tcl -l<br>
查出所有用户信息<br>
