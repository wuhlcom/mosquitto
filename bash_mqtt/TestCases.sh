#!/bin/bash
#auth:wuhongliang
#date:2016-11-24
cuPath=`dirname $0`
source $cuPath/centerControl.sh

#testcase 1
#test the connettion number
testSub(){
	if $localPcFlag;then
        	localSQ&
	fi
	remoteSQ

	if $localPcFlag;then
	        stopSubPub&
	fi
	stopRemoteSub
}

#testcase 2
#test 5 minutes connetstion status
testSubLong(){
	if $localPcFlag;then
        	localSQ&
	fi
	remoteSQ

	sleep 300

	if $localPcFlag;then
		localQuery&
	fi
	remoteQuery

	if $localPcFlag;then
		stopSubPub&
	fi
	stopRemoteSub
}

#testcase 4
#test plenty of sub/pub 
testSubPub(){
	if $localPcFlag;then
	      mqttSubPubLocal&	
	fi
	mqttSubPubRemote

	if $localPcFlag;then
	      stopSubPub&
	fi
	stopRemoteSub
}

#testcase 5
testSubRetain(){
   if $localPcFlag;then
      retainLocal&	
   fi
   retainRemote

   if $localPcFlag;then
     stopSubRetain&
   fi
   stopRetainRemote
}

#subAll
#subCQLocal
#subCcontinue
#subFixLocal
#subFixAll
#subFixRemote
#subCPubR


#pubRetain
#queryPubRLocal
queryPubRRemote
#querySubCR
#subCRetain
