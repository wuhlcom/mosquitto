require './mqtt.rb'
num=5000
host="192.168.10.188"
#host="192.168.10.20"
topic_arr=["only you"]
#cid = "12345"
cid =nil
mqtt=MqClient.new
#mqtt.client_sub_msg(host,topic_arr,cid)
#Thread.abort_on_exception=true
threads=[]

num.times do |i|
# puts "thread #{i}"
# p cid=nil
topic_arr=["rubymqttsub#{i}"]
 thr= Thread.new() do 	
	mqtt.client_sub_msg(host,topic_arr,cid)
    end
 #sleep 0.1
 threads<<thr
end

threads.each{|thr|thr.join}
