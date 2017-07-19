# icpsl
  SoftLayer python client needs to be installed
  
  Download the script files or clone to a local directory.
  
  The IBM Cloud private images need to be present in the same directory
  
  It creates five instances of the specified operating system. By default each instance will have 2 vCPUS, 4 GB Memory and 100GB Hard Disk. To modify the size, modify createslsys.sh.
  
  To install IBM Cloud private, the syntax is
  
  ./icpinstall.sh "softlayer user" "softlayer apikey" "hostname prefix" "domainname" "datacenter" "operatingsystem" "sshkeyname"
  
  Example: ./icpinstall.sh myuser 1234567890ab123def1234 myent mycwcloud.com dal13 UBUNTU_16_64 eicp1
