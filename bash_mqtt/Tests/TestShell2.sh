fun1(){
 param=$1
 echo $param
}

fun2(){
 echo "fun2 output"
 echo `date`
 sleep 15
 echo `date`
}

stopScript(){
          if [ -z "$1" ];then
               scriptName=`basename $0`
          else
               scriptName=$1
          fi
          pids=`ps -ef |grep ${scriptName}|grep "\/bin\/bash"`
          pids=`ps -ef |grep ${scriptName}|grep "\/bin\/bash"|awk -F " " '{print $2}'`
          OLD_IFS="$IFS"
          IFS=" "
          arr=($pids)
          IFS="$OLD_IFS"
          for pid in ${arr[@]};
          do 
            echo $pid
            kill -9 $pid
          done
}

if [ "$1" = "fun1" ];then
  fun1
fi 
