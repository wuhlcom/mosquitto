require './mqtt.rb'
#{
#  :host => nil,
#  :port => nil,
#  :version => '3.1.0',
#  :keep_alive => 15,
#  :clean_session => true,
#  :client_id => nil,
#  :ack_timeout => 5,
#  :username => nil,
#  :password => nil,
#  :will_topic => nil,
#  :will_payload => nil,
#  :will_qos => 0,
#  :will_retain => false,
#  :ssl => false
#}

num=1000
host="192.168.10.200"
#host="192.168.10.20"
topic_arr=["only you"]
#cid = "12345"
cid =nil
#mqtt=MqClient.new
#mqtt.client_sub_msg(host,topic_arr,cid)
#Thread.abort_on_exception=true
threads=[]

`ssh root@#{host} "/home/zhilu/mosquitto/bash_mqtt/mqttAuth.sh 0 #{num} subid ruby"`
num.times do |i|
 topic_arr=["rubymqttsub#{i}"]
 cid="subid#{i}"
 thr= Thread.new() do 	
        mqtt=MqClient.new
        args={username:"mqttclient",password:"mqttclient"}
	mqtt.client_sub(host,topic_arr,cid,args)
#	mqtt.client_sub_msg(host,topic_arr,cid)
    end
 #sleep 0.1
 threads<<thr
end

threads.each{|thr|thr.join}
