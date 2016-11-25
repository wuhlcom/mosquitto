#!/bin/bash
#auth:wuhongliang
#date:2016-11-24
cuPath=`dirname $0`
source $cuPath/centerControl.sh

#testcase 1
#test the connettion number
testConn(){
	if $localPcFlag;then
        	localSQ
	        stopSubPub
	fi
	remoteSQ
	stopRemoteSub
}

#testcase 2
#test 5 minutes connetstion status
testConnTi(){
	if $localPcFlag;then
        	localSQ
	fi
	remoteSQ

	sleep 300

	localQuery
	stopSubPub

	remoteQuery
	stopRemoteSub
}




