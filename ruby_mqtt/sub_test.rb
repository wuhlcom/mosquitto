require 'mqtt'
c = MQTT::Client.new
p MQTT::Client.generate_client_id
host="localhost"
topic="top1"
c.host=host
c.client_id="12345"
c.connect
c.subscribe('top1','tip2')
#message=c.get
#p message
c.get do |topic,message|
 puts "#{topic},#{message}"
end
