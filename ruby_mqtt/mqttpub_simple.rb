require 'mqtt'
host='localhost'
# Publish example
MQTT::Client.connect(host) do |c|
  c.publish('test', 'message')
end
