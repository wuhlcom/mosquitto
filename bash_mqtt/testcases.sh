#!/bin/bash
#auth:wuhongliang
#date:2016-12-14
cuPath=`dirname $0`
source $cuPath/tcMethods.sh

case $1 in
   "suball")
     subAll 
     ;;
   "suballcon")
     subAllContinue
     ;;
   "subccon")
     subCcontinue
     ;;
   "subfixall")
     subFixAll
     ;;
   "subcpubr")
     subCPubR
     ;;
   "subcrecon")
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
