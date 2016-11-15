fun(){
 num=10
}

fun2(){
 fun
 echo $num
}

fun3(){
 a=`fun`
 echo $num
}



#fun2
fun3
