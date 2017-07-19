#!/bin/bash
#This script creates virtual systems in SL
if [ $# -ne 5 ]; then
  echo "Usage: $0 <hostname prefix> < domain name> <datacenter> <OperatingSystem> <softlayer sshkey>"
  echo "datacenter values: ams01, ams03, che01, dal01, dal05, dal06, dal09, dal10, dal12, dal13, fra02, hkg02, hou02, lon02, mel01, mex01, mil01, mon01, osl01, par01, sjc01, sjc03, sao01, seo01, swa01, sng01, syd01, tok02, tor01, wdc01, wdc04"
  echo "Operating System Values: UBUNTU_16_64, REDHAT_7_64, CENTOS_7_64"
  echo "Example: $0 myhost mytest.com dal13 UBUNTU_16_64 acme"
  exit 1
fi

LOG=/tmp/createslsys.log
exec > $LOG 2>&1
NODES=5

HOSTNAME=$1
DOMAIN=$2
DATACENTER=$3
OS=$4
SLKEY=$5

#Create Nodes
COUNTER=1
while [ $COUNTER -le $NODES ]
  do
   slcli -y vs create --hostname=$HOSTNAME-icp$COUNTER --domain=$DOMAIN --cpu 2 --memory 4096 --disk 100 -o $OS --datacenter=$DATACENTER --billing=hourly --key=$SLKEY --network 100
   ((COUNTER++))
  done

echo "Softlayer VS Create Complete"
