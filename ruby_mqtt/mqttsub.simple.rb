require 'mqtt'
# Subscribe example
host='localhost'
host='192.168.10.188'
num = 10
num.times do|i|
	p	topic1="topic#{i}"
	MQTT::Client.connect(host) do |c|
	  # If you pass a block to the get method, then it will loop
	  c.get(topic1) do |topic,message|
	    puts "#{topic}: #{message}"
	  end
	end
end
