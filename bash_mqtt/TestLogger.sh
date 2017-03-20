#如果目录不存在创建目录
#create log file dir
sPath=`dirname $0`
logPath=$sPath/ttlogs
createPath(){
  if [ -z "$1" ];then
        logsPath=$logPath
  else
        logsPath=$1		
  fi
  test -d $logsPath||mkdir $logsPath
}
 
#获取最新的文件名
getLastLogFileName()
{
    path=$1
    cd $path
    lastLog=`ls -l |grep $currentTime | sort -k8rn | head -1 |awk '{print $9}'`
    logFileName=$lastLog
    cd .. 
}

#判断文件名是否存在及文件是否超过指定的大小
isNeedNewFile()
{
    newFile=$1
    if [ -z $newFile ]; then
        return 2
    fi
    
    if [ -f $newFile ];then
        size=`ls -l $newFile | awk '{print $5}'`
        if [ $size -gt $fileSize ];then
           return 0
        else
            return 1
        fi
    else
        return 2
    fi
}

#创建日志文件名
createFile(){
    currentTime=`date "+%Y%m%d%H%M%S"`
    if [ -z "$1" ];then
       logsPath=$logPath
    else
       logsPath=$1		
    fi

    if [ -z "$2" ];then
        fileName="${logsPath}/log-${intf}-${cIP}-${currentTime}.log"
    else
   	fName=$2
	fileName="${logsPath}/${fName}-${intf}-${cIP}-${currentTime}.log"
    fi
    createPath $logsPath
    getLastLogFileName $logsPath
    log_file_name=$logFileName
    isNeedNewFile $log_file_name
    result=$? 

    if [ $result -eq 0 ] || [ $result -eq 2 ];then
        logFileName=$fileName
    else
        logFileName=${logsPath}$log_file_name
    fi
}


#创建日志
writeLog ()
{
     msg=$1   
     if [ -z "$2" ];then
	 level=debug
     else
         level=$2
     fi 
	
    if [ -z "$3" ];then
        logsPath=$logPath
    else
        logsPath=$3		
    fi

    if [ -z "$4" ];then
        fileName="log"
    else
	fileName=$4
    fi
	
    createFile $logsPath $fileName 
    if [ -n "$msg" ];then
      logTime=`date "+[%Y-%m-%d %H:%M:%S]"`
      case $level in
               debug)
                    echo "[DEBUG] $logTime : $msg  " >> $logFileName
               ;;
               info)
                    echo "[INFO] $logTime : $msg  " >> $logFileName
               ;;
               error)
		    echo $logFileName
                    echo "[ERROR] $logTime : $msg  " >> $logFileName
               ;;
              *)
                    echo "error......" >> $logFileName
              ;;
      esac
   fi
}
x=`ps -ef`
echo $x
#writeLog $x
