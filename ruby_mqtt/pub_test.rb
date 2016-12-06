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

pu = MQTT::Client.new
#host="localhost"
host="192.168.10.20"
pubID="testPubID1"
pubMsg="testMessage"
topic="testTopic1"
pu.client_id=pubID
pu.host=host
pu.connect
#publish(topic, payload = '', retain = false, qos = 0) ⇒ Object
pu.publish(topic,pubMsg)
pu.disconnect
