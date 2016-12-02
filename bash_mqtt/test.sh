x=$1
y=$2
testf(){
  a=$1
  b=$2
  c=$3
  echo $a
}

testf2(){
  testf $x $y
}

testf2
