#!/bin/bash
#安装centos7.4+tengine脚本
#官网地址:http://tengine.taobao.org/
chmod -R 777 /usr/local/src/tengine
#时间时区同步，修改主机名
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

ntpdate cn.pool.ntp.org
hwclock --systohc
echo "*/30 * * * * root ntpdate -s 3.cn.poop.ntp.org" >> /etc/crontab

sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/selinux/config
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/selinux/config
sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/sysconfig/selinux 
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/sysconfig/selinux 
setenforce 0 && systemctl stop firewalld && systemctl disable firewalld

rm -rf /var/run/yum.pid 
rm -rf /var/run/yum.pid

#安装依赖包 
yum -y install gcc* autoconf automake zlib zlib-devel openssl openssl-devel pcre* 

#1:解压
cd /usr/local/src/tengine
#wget http://tengine.taobao.org/download/tengine-2.2.2.tar.gz 
mkdir -p /usr/local/tengine/
tar -zxvf tengine-2.2.2.tar.gz -C /usr/local/tengine

#2:创建tengine用户和组
groupadd tengine
useradd -g tengine -s /sbin/nologin tengine

#3:configure配置安装
cd /usr/local/tengine/tengine-2.2.2
mkdir -pv /usr/local/tengine/logs
./configure --prefix=/usr/local/tengine --lock-path=/usr/local/tengine/logs/tengine.lock --user=tengine  --group=tengine --with-http_dav_module --with-http_stub_status_module --with-http_addition_module --with-http_sub_module --with-http_flv_module --with-http_mp4_module --with-pcre --with-http_ssl_module 
make 
make install
chown -Rf tengine:tengine /usr/local/tengine
chmod -Rf 777 /usr/local/tengine/html

#4：验证tengine
#二进制程序：
echo 'export PATH=/usr/local/tengine/sbin:$PATH' > /etc/profile.d/tengine.sh 
source /etc/profile.d/tengine.sh
#头文件输出给系统：
ln -sv /usr/local/tengine/include /usr/include/tengine
#库文件输出：
#echo '/usr/local/tengine/lib' > /etc/ld.so.conf.d/tengine.conf
#让系统重新生成库文件路径缓存
ldconfig
#导出man文件：
cp -r /usr/local/tengine/tengine-2.2.2/man/ /usr/local/tengine/
echo 'MANDATORY_MANPATH                       /usr/local/tengine/man' >> /etc/man_db.conf
source /etc/profile.d/tengine.sh 

/usr/local/tengine/sbin/nginx
/usr/local/tengine/sbin/nginx -V

#5：服务随机启动
cat >> /usr/lib/systemd/system/nginx.service <<EOF
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/usr/local/tengine/logs/nginx.pid
# Nginx will fail to start if /run/nginx.pid already exists but has the wrong
# SELinux context. This might happen when running `nginx -t` from the cmdline.
# https://bugzilla.redhat.com/show_bug.cgi?id=1268621
ExecStartPre=/usr/bin/rm -f /usr/local/tengine/logs/nginx.pid
ExecStartPre=/usr/local/tengine/sbin/nginx -t
ExecStart=/usr/local/tengine/sbin/nginx
ExecReload=/bin/kill -s HUP \$MAINPID
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=process
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload 
systemctl enable nginx.service 
systemctl restart nginx　

#6:调优
sed -i '/sendfile        on;/a\    server_tokens  off;' /usr/local/tengine/conf/nginx.conf
/usr/local/tengine/sbin/nginx -t
/usr/local/tengine/sbin/nginx -s reload
chown -Rf tengine:tengine /usr/local/tengine
rm -rf /usr/local/src/tengine
ps aux |grep tengine


# 使用Tengine的dso_tool,可以用nginx -m查看已经加载的相关模块，用nginx -l查看相关模块列表。
#(Tengine的新特性中的动态加载，在安装后的Tengine的sbin目录里，有nginx和dso_tool两个指令.)	
#下载模块源码
#  cd /usr/local/src
#  git clone git://github.com/hongxiaolong/ngx_slab_stat
#  chown -R tengine:tengine /usr/local/src/ngx_slab_stat
#编译模块
#  /usr/local/tengine/sbin/dso_tool --add-module=/usr/local/src/ngx_slab_stat
#查看编译好的模块
#  ls /usr/local/tengine/modules/ | grep ngx_http_slab_stat
#加载模块
#  vim /usr/local/tengine/conf/nginx.conf
#  dso {
#       load ngx_http_slab_stat_module.so; 
#     }
#重新加载nginx服务
#  nginx -s reload






