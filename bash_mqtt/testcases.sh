#!/bin/bash
#auth:wuhongliang
#date:2016-12-14
currentPath=`dirname $0`
source $currentPath/tcMethods.sh

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
   "subca")
     subCa
     ;;
   "subpubcamu")
     subPubCaMu
     ;;
   "subpubcacon")
     subPubCaCon
     ;;
   "subpubcca")
     subPubCCa
     ;;
   "subcaatopic")
     subCaATopic
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
     subCa
     sleep $tcGap
     subPubCaMu
     sleep $tcGap
     subPubCCa
     sleep $tcGap
     subCaATopic
     sleep $tcGap
     subPubCaCon
     sleep $tcGap
     subCReContinue
     ;;
   *)
    echo "Parameters error!Please check!"
    ;;
esac
