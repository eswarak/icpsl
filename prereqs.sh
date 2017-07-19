#!/bin/bash
#This script updates hosts with required prereqs

LOGFILE=/tmp/prereqs.log
exec > $LOGFILE 2>&1

#Find Linux Distro
if grep -q -i ubuntu /etc/*release
  then
    OSLEVEL=ubuntu
  else
    OSLEVEL=other
fi
echo "Operating System is $OSLEVEL"

ubuntu_install(){
  #Update the source resgitry
  sudo sysctl -w vm.max_map_count=262144
  sudo apt-get update -y
  sudo apt-get install -y python unzip
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce
  service docker start
  sudo apt-get install -y python-pip
  pip install docker-py --upgrade pip
}
crlinux_install(){
  #install epel
  cd /tmp
  wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  yum -y install local epel-release-latest-7.noarch.rpm
  yum clean all
  yum repolist
  #Install net-tools
  yum -y install net-tools
  sysctl -w vm.max_map_count=262144
  #add docker repo and install
  yum install -y yum-utils device-mapper-persistent-data lvm2
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum-config-manager --enable docker-ce-edge
  yum-config-manager --enable docker-ce-testing
  yum-config-manager --disable docker-ce-edge
  yum -y makecache fast
  yum -y install docker-ce
  systemctl enable docker
  systemctl start docker
  yum -y install python-pip
  pip install docker-py --upgrade pip
}

if [ "$OSLEVEL" == "ubuntu" ]; then
  ubuntu_install
else
  crlinux_install
fi

echo "Complete.."
