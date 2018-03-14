#!/bin/bash

j1=java-1.8.0-openjdk-1.8.0.65-3.b17.el7.x86_64.rpm
j2=java-1.8.0-openjdk-devel-1.8.0.65-3.b17.el7.x86_64.rpm
j3=java-1.8.0-openjdk-headless-1.8.0.65-3.b17.el7.x86_64.rpm
j4=giflib-4.1.6-9.el7.x86_64.rpm
j5=javapackages-tools-3.4.1-11.el7.noarch.rpm
j6=libfontenc-1.1.2-3.el7.x86_64.rpm
j7=libICE-1.0.9-2.el7.x86_64.rpm
j8=libSM-1.2.2-2.el7.x86_64.rpm
j9=libXfont-1.5.1-2.el7.x86_64.rpm
j10=lksctp-tools-1.0.13-3.el7.x86_64.rpm
j11=python-javapackages-3.4.1-11.el7.noarch.rpm
j12=ttmkfdir-3.0.9-42.el7.x86_64.rpm
j13=tzdata-java-2015g-1.el7.noarch.rpm
j14=xorg-x11-fonts-Type1-7.5-9.el7.noarch.rpm
j15=xorg-x11-font-utils-7.5-20.el7.x86_64.rpm;
j16=libX11-1.6.3-2.el7.x86_64.rpm
j17=libXext-1.3.3-3.el7.x86_64.rpm
j18=libXi-1.7.4-2.el7.x86_64.rpm
j19=libXrender-0.9.8-2.1.el7.x86_64.rpm
j20=libXtst-1.2.2-2.1.el7.x86_64.rpm
j21=libjpeg-turbo-1.2.90-5.el7.x86_64.rpm
j22=libpng-1.5.13-5.el7.x86_64.rpm
j23=libX11-common-1.6.3-2.el7.noarch.rpm
j24=libxcb-1.11-4.el7.x86_64.rpm
j25=fontconfig-2.10.95-7.el7.x86_64.rpm
j26=libXau-1.0.8-2.1.el7.x86_64.rpm
j27=fontpackages-filesystem-1.44-8.el7.noarch.rpm

zoocfg=/var/zookeeper/zookeeper-3.4.6/conf/zoo.cfg
kafkas=/var/kafka/kafka_2.12-0.10.2.1/config/server.properties
webconfig=/root/kafka-eagle-web-1.1.3/conf/system-config.properties


#配置服务器信息
read -p "请输入本次要配置zookeeper/kafka的服务器数量：" servernum
for i in `seq $servernum`
do
read -p "请输入服务器$i的ip地址:" ip
server_[$i]=$ip
done

#/etc/hosts
for i in `seq $servernum`
do
echo "${server_[$i]} ${server_[$i]}" >> ${PWD}/auto/hosts
done

#/var/kafka/kafka_2.12-0.10.2.1/config/server.properties

echo -n "zookeeper.connect=" >> ${PWD}/auto/zookeeper_connect

for i in `seq $servernum`
do
echo -n "${server_[$i]}:2181," >> ${PWD}/auto/zookeeper_connect
done

for i in `seq $servernum`
do
sed -i 's/,$//' ${PWD}/auto/zookeeper_connect
done

#/var/zookeeper/zookeeper-3.4.6/conf/zoo.cfg

for i in `seq $servernum`
do
echo "server.$i=${server_[$i]}:3333:4444" >> ${PWD}/auto/xuanju_port
done


#安装文件的复制传输
for i in `seq $servernum`
do
scp -r ${PWD}/auto/ root@${server_[$i]}:/root
done

#系统配置

#关闭防火墙
#禁用防火墙
#修改时区为中国时区（Asia/Shanghai）
#重启系统日志，重新加载时区
#关闭selinux 临时关闭
#禁用selinux
for i in `seq $servernum`
do
pdsh -w ${server_[$i]} "systemctl stop firewalld;
systemctl disable firewalld;
yes|cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime;
systemctl restart rsyslog;
setenforce Permissive;
sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config"
done

#修改ulimt=65535
#查看结果
for i in `seq $servernum`
do 
pdsh -w ${server_[$i]} "echo "* soft nofile 65535" >> /etc/security/limits.conf;
echo "* hard nofile 65535" >> /etc/security/limits.conf;
ulimit -n"
done

#安装java环境
#添加JAVA_HOME
for i in `seq $servernum`
do 
pdsh -w ${server_[$i]} "cd /root/auto/javapackages;
rpm -ivh $j1 $j2 $j3 $j4 $j5 $j6 $j7 $j8 $j9 $j10 $j11 $j12 $j13 $j14 $j15 \
$j16 $j17 $j18 $j19 $j20 $j21 $j22 $j23 $j24 $j25 $j26 $j27;
cd /root/auto;
echo -n  'export JAVA_HOME=/etc/alternatives/' >> /etc/profile;
echo 'java_sdk_1.8.0_openjdk/' >> /etc/profile;
echo 'export PATH=\$JAVA_HOME/bin:\$PATH' >> /etc/profile;
echo -n 'export CLASSPATH=.:\$JAVA_HOME/lib/dt.jar:' >> /etc/profile;
echo '\$JAVA_HOME/lib/tools.jar' >> /etc/profile;
source /etc/profile"
done

#添加hosts

for i in `seq $servernum`
do 
pdsh -w ${server_[$i]} "cat /root/auto/hosts >> /etc/hosts"
done

#Zookeeper配置
#配置数据存放目录
#添加dataDir
for i in `seq $servernum`
do 
pdsh -w ${server_[$i]} "cd /root/auto;
mkdir /var/zookeeper;
tar -zxvf zookeeper-3.4.6.tar.gz;
mv zookeeper-3.4.6 /var/zookeeper;
mkdir /var/data;
mkdir /var/data/zookeeper;
cd /var/zookeeper/zookeeper-3.4.6/conf;
cp zoo_sample.cfg zoo.cfg;
sed -i 's/dataDir=\/tmp\/zookeeper/dataDir=\/var\/data\/zookeeper/' $zoocfg"
done

#添加选举端口

for i in `seq $servernum`
do
pdsh -w ${server_[$i]} "cat /root/auto/xuanju_port >> $zoocfg"
done

#添加myid
for i in `seq $servernum`
do
pdsh -w ${server_[$i]} "echo "$i" > /var/data/zookeeper/myid"
done


for i in `seq $servernum`
do 
pdsh -w ${server_[$i]} "cd /root/auto;
mv /root/auto/zookeeper/log4j.properties /var/zookeeper/zookeeper-3.4.6/conf;
mv /root/auto/zookeeper/zookeeper.service  /usr/lib/systemd/system;
systemctl daemon-reload;
systemctl enable zookeeper;
systemctl start zookeeper"
done


#kafka配置

for i in `seq $servernum`
do 
pdsh -w ${server_[$i]} "cd /root/auto;
mkdir /var/kafka;
tar -zxvf kafka_2.12-0.10.2.1.tgz;
mv kafka_2.12-0.10.2.1 /var/kafka"
done

#Modify configuration 修改kafka配置

for i in `seq $servernum`
do
pdsh -w ${server_[$i]} "sed -i "s/broker.id=0/broker.id=$i/" $kafkas"
done

for i in `seq $servernum`
do 
pdsh -w ${server_[$i]} "echo 'port=9092' >> $kafkas;
echo '#数据保存路径' >> $kafkas;
sed -i '/log.dirs=\/tmp\/kafka-logs/d' $kafkas;
echo 'log.dirs=\/var\/data/kafka-logs' >> $kafkas;
sed -i '/zookeeper.connect=localhost:2181/d' $kafkas"
done

for i in `seq $servernum`
do
pdsh -w ${server_[$i]} "echo '#本机ip' >> $kafkas;"
pdsh -w ${server_[$i]} "echo "host.name=${server_[$i]}" >> $kafkas;"
pdsh -w ${server_[$i]} "echo '#本机ip地址' >> $kafkas;"
pdsh -w ${server_[$i]} "echo "advertised.host.name =${server_[$i]}" >> $kafkas;" 
done


for i in `seq $servernum`
do
pdsh -w ${server_[$i]} "cat /root/auto/zookeeper_connect >> $kafkas"
done



#修改kafka日志配置
#增加systemctl配置
#启动 kafka
for i in `seq $servernum`
do 
pdsh -w ${server_[$i]} "cd /root/auto;
mv /root/auto/kafka/log4j.properties /var/kafka/kafka_2.12-0.10.2.1/conf;
mv /root/auto/kafka/kafka.service  /usr/lib/systemd/system;
systemctl daemon-reload;
systemctl enable kafka;
systemctl start kafka"
done


#kafka-WEB管理界面

pdsh -w ${server_[$servernum]} "cd /root/auto;
tar -zxvf kafka-eagle-web-1.1.3-bin.tar.gz;
mv /root/auto/kafka-eagle-web-1.1.3 /root/kafka-eagle-web-1.1.3;
sed -i "/cluster1.zk.list=tdn1:2181:tdn2:2181,tdn3:2181/d" $webconfig"

pdsh -w ${server_[$servernum]} "echo -n "cluster1.zk.list=" >> $webconfig"

for i in `seq $servernum`
do
pdsh -w ${server_[$servernum]} "echo -n "${server_[$i]}:2181," >> $webconfig"
done

pdsh -w ${server_[$servernum]} "sed -i 's/,$//' $webconfig"

pdsh -w ${server_[$servernum]} "
echo "export KE_HOME=/data/soft/new/kafka-eagle" >> /etc/profile;
echo 'export PATH=\$PATH:\$KE_HOME/bin' >> /etc/profile;
source /etc/profile;
cd kafka-eagle-web-1.1.3/bin;
chmod +x ke.sh;
./ke.sh start"

#创建kafka的topic

pdsh -w ${server_[$servernum]} "cd /var/kafka/kafka_2.12-0.10.2.1;
bin/kafka-topics.sh --create --zookeeper localhost:2181 \
--replication-factor 3 --partitions 16 --topic micro-tollgate;
bin/kafka-topics.sh --create --zookeeper localhost:2181 \
--replication-factor 3 --partitions 16 --topic electron-tollgate;
bin/kafka-topics.sh --create --zookeeper localhost:2181 \
--replication-factor 3 --partitions 16 --topic normal-tollgate;
bin/kafka-topics.sh --create --zookeeper localhost:2181 \
--replication-factor 3 --partitions 16 --topic sendTopic"

clear

echo "--------------安装已完成----------------
WEB管理界面地址为：${server_[$servernum]}:8048/ke
---------------感谢使用-----------------"

rm -f ${PWD}/auto/hosts
rm -f ${PWD}/auto/zookeeper_connect
rm -f ${PWD}/auto/xuanju_port
