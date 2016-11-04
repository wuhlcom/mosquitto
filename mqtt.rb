require 'mqtt'

#Default attribute values
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

class MqClient
 
	#init client 
	#
	#params
	#   host,mqtt srv ip or domain
	#   cid,client id
	#   args,client attribudes
	def clientobj(host,cid=nil,args={})
	  fail 'topic must be string Array' unless topic.kind_of?(Array)
	  client= MQTT::Client.new
	  client.host=host
	  client.client_id=cid.to_s unless cid.nil?
	  args.each do |key,value|
	     client.send("#{key}=",value) if client.respond_to?(key.to_sym)&& !args[key].nil?   
	  end
	  client.connect
	  client
	end

	#client_sub sub message long time
	#
	#params
	#   host,mqtt srv ip or domain
	#   topic,mqtt topic must be string array
	#   cid,client id
	#   args,client attribudes
	def client_sub_msg(host,topic,cid=nil,args={})
	  client= clientobj(host,cid,args)
	  puts "mqtt client '#{client.client_id}' conneted"
	  client.subscribe(topic.join(","))
	  client.get do |topic_single,message|
		puts "#{topic_single}:#{message}"
	  end
	end


	#client_pub publich message
	#
	#params
	#   host,mqtt srv ip or domain
	#   topic,mqtt topic must be string array
	#   cid,client id
	#   args,client attribudes
	def client_pub_msg(host,topic,msg="",cid=nil,retain=false,qos=0,args={})
	  client = clientobj(host,cid,args)
	  client.publish(topic,msg,retain,qos)
	end
	
	def generate_cid(prefix='ruby',lengh=16)
	   MQTT::Client.geneate_client_id(prefix,lenth)
	end
end
