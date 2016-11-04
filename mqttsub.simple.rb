require 'mqtt'
# Subscribe example
host='localhost'
MQTT::Client.connect(host) do |c|
  # If you pass a block to the get method, then it will loop
  c.get('test') do |topic,message|
    puts "#{topic}: #{message}"
  end
end
