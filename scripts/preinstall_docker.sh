################################################################################
# Choose Versions (everything else will be 'latest' builds)
################################################################################
ELASTIC_VERSION=6.3.0
BRO_VERSION=2.5.4
SPLUNK_VERSION=7.1.0

read -p "Domain? " DOMAIN
echo -e "\n!!You must enter the exact same admin password during install!!"
read -p "Admin Password? " PASSWORD

################################################################################
# Prepare the directories
################################################################################
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

systemctl stop rhsm

mkdir -p ./rpm/updates
mkdir -p ./rpm/extras
mkdir -p ./images
mkdir -p ./tar/bro
mkdir -p ./tar/stenographer
mkdir -p ./rpm/docker
mkdir -p ./rpm/ipa-client
mkdir -p ./rpm/filebeat
mkdir -p ./rpm/stenographer
mkdir -p ./suricata/rules
mkdir -p /root/rpmbuild/BUILD
mkdir -p /root/rpmbuild/BUILDROOT
mkdir -p /root/rpmbuild/SPECS
mkdir -p /root/rpmbuild/SOURCES

rm -rf /root/rpmbuild/BUILD/*
rm -rf /root/rpmbuild/BUILDROOT/*
rm -rf /root/rpmbuild/SPECS/*
rm -rf /root/rpmbuild/SOURCES/*

################################################################################
# RPMs
################################################################################
sed -e "s/repo_gpgcheck=1/repo_gpgcheck=0/g" -e "s/localpkg_gpgcheck=1/localpkg_gpgcheck=0/g" -i /etc/yum.conf
yum clean all
yum -y -q -e 0 install ntp git wget rng-tools
systemctl restart ntpd
curl -L -o ./rpm/extras/epel-release-7-11.noarch.rpm -O http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-11.noarch.rpm
rpm --import http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7
yum -y -q -e 0 install ./rpm/extras/epel-release-7-11.noarch.rpm
yum -y -q -e 0 install rpm-build elfutils-libelf rpm rpm-libs rpm-python

# Docker
yum -y -q -e 0 install yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum -y -q -e 0 install docker-ce
# Start Docker Service
systemctl start docker

# FileBeat
curl -L -o ./rpm/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm

# Bro
curl -L -o ./bro/bro-$BRO_VERSION.tar.gz -O https://www.bro.org/downloads/bro-$BRO_VERSION.tar.gz
git clone https://github.com/J-Gras/bro-af_packet-plugin
tar czvf bro/bro-af_packet-plugin.tar.gz bro-af_packet-plugin
################################################################################
# Docker Containers
################################################################################
# GoGS
# Acquire GoGS
docker pull gogs/gogs
# Rename GoGS image name to something simpler
docker tag gogs/gogs gogs
# Save GoGS
docker save -o ./images/gogs.docker gogs

# ElasticSearch (for ELK)
docker pull docker.elastic.co/elasticsearch/elasticsearch:$ELASTIC_VERSION
docker tag docker.elastic.co/elasticsearch/elasticsearch:$ELASTIC_VERSION elasticsearch
docker rmi docker.elastic.co/elasticsearch/elasticsearch:$ELASTIC_VERSION
docker save -o ./images/elasticsearch.docker elasticsearch

# Logstash
docker pull docker.elastic.co/logstash/logstash:$ELASTIC_VERSION
docker tag docker.elastic.co/logstash/logstash:$ELASTIC_VERSION logstash
docker save -o ./images/logstash.docker logstash
docker rmi docker.elastic.co/logstash/logstash:$ELASTIC_VERSION

# Kibana
docker pull docker.elastic.co/kibana/kibana:$ELASTIC_VERSION
docker tag docker.elastic.co/kibana/kibana:$ELASTIC_VERSION kibana
docker save -o ./images/kibana.docker kibana
docker rmi docker.elastic.co/kibana/kibana:$ELASTIC_VERSION

# Splunk
docker pull splunk/splunk:$SPLUNK_VERSION
docker tag splunk/splunk:$SPLUNK_VERSION splunk
docker save -o ./images/splunk.docker splunk
docker rmi splunk/splunk:$SPLUNK_VERSION

# Universal Splunk Forwarder
docker pull splunk/universalforwarder:$SPLUNK_VERSION
docker tag splunk/universalforwarder:$SPLUNK_VERSION universalforwarder
docker save -o ./images/universalforwarder.docker universalforwarder
docker rmi splunk/universalforwarder:$SPLUNK_VERSION

# BusyBox for Splunk
docker pull busybox
docker save -o ./images/busybox.docker busybox

# FreeIPA
docker pull adelton/freeipa-server:centos-7
docker tag adelton/freeipa-server:centos-7 freeipa
docker save -o ./images/freeipa.docker freeipa
docker rmi adelton/freeipa-server:centos-7

# MongoDB for RocketChat
docker pull mongo
docker save -o ./images/mongo.docker mongo

# RocketChat
docker pull rocketchat/rocket.chat
docker tag rocketchat/rocket.chat rocketchat
docker save -o ./images/rocketchat.docker rocketchat
docker rmi rocketchat/rocket.chat

# Nginx
docker pull nginx
docker save -o ./images/nginx.docker nginx

# OwnCloud
docker pull owncloud
docker save -o ./images/owncloud.docker owncloud

# TheHive
docker pull certbdf/thehive
docker tag certbdf/thehive thehive
docker save -o ./images/thehive.docker thehive
docker rmi certbdf/thehive

# Cortex for TheHive
docker pull certbdf/cortex
docker tag certbdf/cortex cortex
docker save -o ./images/cortex.docker cortex
docker rmi certbdf/cortex

# Old version of ElasticSearch for TheHive
docker pull docker.elastic.co/elasticsearch/elasticsearch:5.5.3
docker tag docker.elastic.co/elasticsearch/elasticsearch:5.5.3 eshive
docker save -o ./images/eshive.docker eshive
docker rmi docker.elastic.co/elasticsearch/elasticsearch:5.5.3

################################################################################
# Big Files
################################################################################
curl -L -o ./suricata/rules/emerging-all.rules https://rules.emergingthreats.net/open/snort-2.9.0/emerging-all.rules
curl -L -o ./logstash/GeoLite2-City.tar.gz http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz

################################################################################
# Generate SSL Certificates (This needs to be done yearly!)
################################################################################
bash scripts/generateCerts.sh $DOMAIN $PASSWORD

################################################################################
# Cleanup
################################################################################
sed -e "s/repo_gpgcheck=0/repo_gpgcheck=1/g" -i /etc/yum.conf
rm -rf bro-af_packet-plugin
rm -rf rpmbuild
rm -rf *.tar.gz
rm -rf metron-bro-plugin-kafka
rm -rf tar
rm -rf /tmp/*.yumtx

tar -czv --remove-files -f install-$(date '+%Y%b%d' | awk '{print toupper($0)}').tar.gz *
