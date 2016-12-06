require 'mqtt'
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
#MQTT::Client.generate_client_id("1234",0)
#host="localhost"

srv_ip="192.168.10.200"
srv_ip="192.168.10.20"
srv_port="1883"
clientsNum=2000
clientsArr=[]
#c = MQTT::Client.new
#c.host=srv_ip
#c.keep_alive=60
clientsNum.times do|num|
	num+=1
	c = MQTT::Client.new
	topic="testTopic#{num}"
	subID="testSubID#{num}"
	c.client_id=subID
	c.host=srv_ip
#	c.username="mqttclient" 
#	c.password="mqttclient"
	#c.keep_alive=60
	c.connect
	#多个主题
	#c.subscribe('top1','tip2')
	c.subscribe(topic)
	#使用get接收一次pub后就会断开
	#message=c.get
       #使用代码块可以持续接收pub 消息
       #c.get do |topic,message|
       # puts "#{topic},#{message}"
       #end
      clientsArr<<c     
end
sleep 300
clientsArr.each do|c|
	c.disconnect
end


