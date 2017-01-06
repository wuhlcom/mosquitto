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
     subCContinue
     ;;
   "subfixall")
     subFixAll
     ;;
   "subcpubr")
     subCPubR
     ;;
   "subcrecon")
     subCReContinue
     ;;
   "all")
     subAll
     sleep $tcGap
     subAllContinue    
     sleep $tcGap
     subCContinue
     sleep $tcGap
     subFixAll
     sleep $tcGap
     subCPubR
     sleep $tcGap
     subCReContinue
   ;;
   *)
    echo "Parameters error!Please check!"
    ;;
esac
