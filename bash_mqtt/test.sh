testf(){
  args1=$1
  if [ -z "$2" ];then
    args2="no \$2"
  else
    args2=$2
  fi 
  echo ${args1}
  echo ${args2}  
}

param1=$1
param2=$2
if [ $# = 1 ];then
	echo oneone 
	testf $param1
else
	echo twotwo
	testf $param1 $param2
fi

