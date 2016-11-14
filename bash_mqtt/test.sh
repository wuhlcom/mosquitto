#log content time
function logtime {
  t=`date +"[%Y-%m-%d %H:%M:%S]"`
  echo ${t}
}

if [ -z $1 ];then
 num=100
else
 num=$1
fi
echo $num

funtion1(){
 te1num=1234
}

funtion2(){
   tel
   echo $telnum
}
#source client_monitor.sh
#report&

source logger.sh
cpu=`top_cpu`
echo $cpu
#write_log "test" 
write_mqtt_log 

