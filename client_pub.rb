 require './mqtt.rb'
num=10
host="localhost"
cid = "67890"
topic="only you"
msg = "is a SB"
mqtt=MqClient.new
mqtt.client_pub_msg(host,topic,msg,cid)

