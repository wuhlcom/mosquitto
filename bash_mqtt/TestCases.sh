#!/bin/bash
#auth:wuhongliang
#date:2016-11-24
cuPath=`dirname $0`
source $cuPath/centerControl.sh

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
   *)
    subAll
    subAllContinue    
    subCcontinue
    subFixAll
    subCPubR
    subCRecontinue
    ;;
esac
