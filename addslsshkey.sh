#!/bin/bash
#This script creates checks and creates a key and adds to Softlayer

if [ $# -lt 2 ]; then
  echo "Usage: $0 sshkeyname {true|false}"
  exit 1
fi
SLKEY=$1
LOGFILE=/tmp/addslsshkey.log
exec > $LOGFILE 2>&1

#create a ddc key if not present
if [ ! -f ~/.ssh/$SLKEY.rsa ]; then
  cd ~/.ssh
  ssh-keygen -t rsa -N '' -f $SLKEY.rsa
fi

#check if sshkey exists in SL
slcli sshkey list | grep $SLKEY
if [ $? -ne 0 ]; then
 slcli sshkey add -f ~/.ssh/$SLKEY.rsa.pub $SLKEY
else
  if [ $2 ]; then
    sshkeyid=`slcli sshkey list | grep $SLKEY | awk '{print $1}'`
    slcli -y sshkey remove $sshkeyid
    slcli sshkey add -f ~/.ssh/$SLKEY.rsa.pub $SLKEY
  else
    echo "Key exists, please try a new keyname"
    exit 1
  fi
fi

echo "SSHKey add to SoftLayer Complete"
