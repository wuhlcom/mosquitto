#mport paho.mqtt.client as mqtt
#import time

#client = locals()
import paho.mqtt.client as mqtt
import time
arr=[]
for i in range(1,1000):
        client = mqtt.Client()
        client.connect("192.168.10.20", 1883, 5)
        time.sleep(0.05)
        client.subscribe("wahaha")
        client.loop_forever()
        arr.append(client)
        print i
#time.sleep(10)
#client1._send_pingreq()
time.sleep(60)
