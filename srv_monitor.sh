server_ip=192.168.10.188
client_ip=192.168.10.166
#ssh zhilu@$server_ip
ssh zhilu@$server_ip "netstat -apnt|grep $server_ip:1883|grep $client_ip|grep ESTABLISHED|wc -l"

