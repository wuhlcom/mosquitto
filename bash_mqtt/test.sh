   function mqtt_sub {  
	  topoic="sensortopicpc166$i"
          id="clientidpc166$i"
          $(mosquitto_sub -t $topic -h $host -q $j -i $id -k 120)
          echo client  \'$id\' sub topic \'$topic\'
          j=`expr $j + 1`
          if [ $j -ge 3 ]; then
                  j=0
          fi
 }
