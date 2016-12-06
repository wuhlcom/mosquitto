 require './mqtt.rb'
#host="localhost"
host="192.168.10.20"
cid = "67890"
topic="topic1"
msg = "is a SB"
mqtt=MqClient.new
mqtt.client_pub_msg(host,topic,msg,cid)

