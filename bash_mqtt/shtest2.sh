fun1(){
 param1=1
 param2=2
}

fun2(){
  param1=0
  param2=0
  fun1
  echo $param1
  echo $param2
}

fun2
