require 'mqtt'
pu = MQTT::Client.new
host="localhost"
pu.host=host
pu.connect
pu.publish('top1',"ttt")

