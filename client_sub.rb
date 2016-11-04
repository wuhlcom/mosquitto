require './mqtt.rb'
num=1000
host="localhost"
host="192.168.10.188"
topic_arr=["only you"]
cid = "12345"
mqtt=MqClient.new
#mqtt.client_sub_msg(host,topic_arr,cid)
Thread.abort_on_exception=true
threads=[]

num.times do |i|
# puts "thread #{i}"
 p cid="Fest_#{i}"
 thr= Thread.new() do 	
	mqtt.client_sub_msg(host,topic_arr,cid)
    end
 sleep 0.1
 threads<<thr
end

threads.each{|thr|thr.join}
