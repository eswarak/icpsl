#!/bin/bash
# This script combines all scripts to create Docker Data Center
#
if [ $# -lt 7 ]; then
  echo "Usage: $0 <softlayer user> <softlayer apikey> <hostname prefix> <domainname> <datacenter> <operatingsystem> <sshkeyname>"
  echo "datacenter values: ams01, ams03, che01, dal01, dal05, dal06, dal09, dal10, dal12, dal13, fra02, hkg02, hou02, lon02, mel01, mex01, mil01, mon01, osl01, par01, sjc01, sjc03, sao01, seo01, swa01, sng01, syd01, tok02, tor01, wdc01, wdc04"
  echo "operatingsystem values: UBUNTU_16_64, REDHAT_7_64, CENTOS_7_64"
  echo "Example: $0 eswara 1234567890ab123def1234 myent mycwcloud.com dal13 UBUNTU_16_64 eicp1"
  exit 1
fi

# Check for files
if [ ! -e addslsshkey.sh ] && [ ! -e createslsys.sh ] && [ ! -e prereqs.sh ] && [ ! -e bm-cloud-private-installer-1.2.0.tar.gz ] && [ ! -e ibm-cloud-private-x86_64-1.2.0.tar.gz ] ;then
  echo "Required files are not there, ensure the required files are present in current working directory"
  exit 1
fi

logfile=/tmp/createmaster.log
exec > $logfile 2>&1

SLUSER=$1
SLAPIKEY=$2
HOSTNAME=$3
DOMAIN=$4
DATACENTER=$5
OS=$6
SLSSHKEY=$7

# Add SSH Key to Softlayer
echo "Setting up Softlayer SSH Key"
echo "Running ./addslsshkey $SLSSHKEY true"
./addslsshkey.sh $SLSSHKEY true
if [ $? -ne 0 ]; then
   echo "Error adding sshkeys..." 
   exit 1
fi

# Create Virtual Systems in SL
echo "Creating Virtual Systems in SL. Required arguments are hostnameprefix, domainname, datacenter, operatingsystem, softlayer sshkey"
echo "Running ./createslsys.sh $HOSTNAME $DOMAIN $DATACENTER $OS $SLSSHKEY" 
./createslsys.sh $HOSTNAME $DOMAIN $DATACENTER $OS $SLSSHKEY
if [ $? -ne 0 ]; then
   echo "Error creating systems in Softlayer..."
   exit 1
fi
#Wait for the machines to comeup
sleep 300

# Create hosts file for all nodes
echo "127.0.0.1 localhost.localdomain localhost" > /tmp/hosts
for i in `slcli vs list|grep $HOSTNAME|awk '{print $2}'`
do
  SYSSTAT=`slcli vs list|grep $i|awk '{print $6}'`
  echo "Waiting for system to be ready"
  while [ "$SYSSTAT" != "NULL" ]
    do
      sleep 10
      SYSSTAT=`slcli vs list|grep $i|awk '{print $6}'`
      printf .
    done
   slcli vs list|grep $i|awk '{print $3, $2".""'$DOMAIN'", $2}' >> /tmp/hosts
  done

# Check and Install Master Controller
# Check Status of the the machine
for i in `slcli vs list|grep $HOSTNAME|awk '{print $2}'`
do
  ICPIP=`slcli vs detail $i|grep public_ip|awk '{print $2}'`
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/$SLSSHKEY.rsa /tmp/hosts root@$ICPIP:/etc/
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/$SLSSHKEY.rsa prereqs.sh root@$ICPIP:/tmp/
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/$SLSSHKEY.rsa root@$ICPIP "cd /tmp;chmod 755 prereqs.sh; ./prereqs.sh"
  if [ $? -ne 0 ]; then
    echo "Error Installing prereqs, check the logs"
    exit 1
  fi
done

# Copy, config and install IBM Cloud private
# Considering first node as master, second node as proxy and rest as workernodes
MASTERIP=`slcli vs detail $HOSTNAME-icp1|grep public_ip|awk '{print $2}'`
echo "[master]" > /tmp/icphosts
echo $MASTERIP >> /tmp/icphosts
echo "">> /tmp/icphosts
echo "[worker]" >> /tmp/icphosts
PROXYIP=`slcli vs detail $HOSTNAME-icp2|grep public_ip|awk '{print $2}'`
for j in {3..5}
  do
    WORKERIP=`slcli vs detail $HOSTNAME-icp$j|grep public_ip|awk '{print $2}'`
    echo $WORKERIP >> /tmp/icphosts
  done
echo "">> /tmp/icphosts
echo "[proxy]" >> /tmp/icphosts
echo $PROXYIP >> /tmp/icphosts

# Copy the images to master controller
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/$SLSSHKEY.rsa ibm-cloud-private-installer-1.2.0.tar.gz root@$MASTERIP:/tmp
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/$SLSSHKEY.rsa ibm-cloud-private-x86_64-1.2.0.tar.gz root@$MASTERIP:/tmp
#Expand the images
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/$SLSSHKEY.rsa root@$MASTERIP "cd /tmp; tar zxf ibm-cloud-private-installer-1.2.0.tar.gz; mv ibm-cloud-private-1.2.0 /opt/;cd /opt/ibm-cloud-private-1.2.0; mv /tmp/ibm-cloud-private-x86_64-1.2.0.tar.gz images/"

#Copy hosts file
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/$SLSSHKEY.rsa /tmp/icphosts root@$MASTERIP:/opt/ibm-cloud-private-1.2.0/hosts
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/$SLSSHKEY.rsa  ~/.ssh/$SLSSHKEY.rsa root@$MASTERIP:/opt/ibm-cloud-private-1.2.0/ssh_key

#Run the install
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/$SLSSHKEY.rsa root@$MASTERIP "cd /opt/ibm-cloud-private-1.2.0; tar xf images/ibm-cloud-private-x86_64-1.2.0.tar.gz -C images; docker load -i images/ibm-cloud-private-x86_64-1.2.0.tar; docker run -e LICENSE=accept --net=host --rm -t -v \"\$(pwd)\":/installer/cluster ibmcom/cfc-installer:1.2.0-ee install; echo $?"

  if [ $? -ne 0 ]; then
    echo "Error Installing prereqs, check the logs"
    exit 1
  fi

echo "Installation Complete..."
