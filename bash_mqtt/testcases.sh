#!/bin/bash
#auth:wuhongliang
#date:2016-11-24
cuPath=`dirname $0`
#source $cuPath/centerControl.sh
source $cuPath/tcMethods.sh

#testcase 1
case $1 in
   "suball")
     subAll 
     ;;
   "suballc")
     subAllContinue
     ;;
   "subcc")
     subCcontinue
     ;;
   "subfix")
     subFixAll
     ;;
   "subcpubr")
     subCPubR
     ;;
   "subcre")
     subCRecontinue
     ;;
   "all")
     subAll
     sleep $tcGap
     subAllContinue    
     sleep $tcGap
     subCcontinue
     sleep $tcGap
     subFixAll
     sleep $tcGap
     subCPubR
     sleep $tcGap
     subCRecontinue
   ;;
   *)
    echo "Param error!Please check!"
    ;;
esac
