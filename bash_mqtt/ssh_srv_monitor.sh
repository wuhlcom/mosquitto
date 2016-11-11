#!/bin/sh
#服务进程需要监控：dispatch 、topicroute 、mqtt_process、access
server_ip=192.168.10.188
client_ip=192.168.10.166
#ssh zhilu@$server_ip
ssh zhilu@$server_ip "netstat -apnt|grep $server_ip:1883|grep $client_ip|grep ESTABLISHED|wc -l"
ssh zhilu@$server_ip "ps -ax |grep "dispatch\|topicroute\|mqtt_process\|access"



