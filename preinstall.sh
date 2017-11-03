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

ELASTIC_VERSION=5.6.3
BRO_VERSION=2.5.1

rm -rf /root/rpmbuild/BUILD/*
rm -rf /root/rpmbuild/BUILDROOT/*
rm -rf /root/rpmbuild/SPECS/*
rm -rf /root/rpmbuild/SOURCES/*

################################################################################
# RPMs
################################################################################
# Updates
yum -y update --downloadonly --downloaddir=./rpm/updates
# These break the network connection for some reason.
rm -rf ./rpm/updates/NetworkManager*

# Extras
yum -y install --downloadonly --downloaddir=./rpm/extras git epel-release wget rng-tools
yum -y localinstall ./rpm/extras/*.rpm
yum -y install --downloadonly --downloaddir=./rpm/extras rpm-build elfutils-libelf rpm rpm-libs rpm-python
yum -y localinstall ./rpm/extras/*.rpm

# Docker
yum -y install --downloadonly --downloaddir=./rpm/docker yum-utils device-mapper-persistent-data lvm2
yum -y localinstall ./rpm/docker/*.rpm
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum -y install --downloadonly --downloaddir=./rpm/docker docker-ce
yum -y localinstall ./rpm/docker/*.rpm
# Start Docker Service
systemctl start docker

# IPA-client
yum -y install --downloadonly --downloaddir=./rpm/ipa-client ipa-client

# FileBeat
curl -L -o ./rpm/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm
yum -y install --downloadonly --downloaddir=./rpm/filebeat ./rpm/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm

# Bro
yum -y install --downloadonly --downloaddir=./rpm/bro bind-devel bison cmake flex GeoIP-devel gcc-c++ gperftools-devel jemalloc-devel libpcap-devel openssl-devel python2-devel python-tools swig zlib-devel python-devel kernel-devel kernel-headers librdkafka-devel
yum -y localinstall ./rpm/bro/*.rpm
curl -L -o ./tar/bro/bro-$BRO_VERSION.tar.gz -O https://www.bro.org/downloads/bro-$BRO_VERSION.tar.gz
mv ./tar/bro/bro-$BRO_VERSION.tar.gz  /root/rpmbuild/SOURCES/
git clone https://github.com/dcode/rpmbuild.git
sed -i -e "s@--strip-components=1@@g" -e "s@%{_libdir}/broctl/*\.p*@@" -e "s@%files -n broctl@%files -n broctl"$'\\\n'"%exclude %{_libdir}/broctl/broccoli*.p*"$'\\\n'"%exclude %{_libdir}/broctl/_broccoli_intern.so@g" ./rpmbuild/SPECS/bro.spec
mv ./rpmbuild/SPECS/bro.spec /root/rpmbuild/SPECS/bro.spec
git clone https://github.com/J-Gras/bro-af_packet-plugin
pushd ./bro-af_packet-plugin
tar czvf ../bro-plugin-afpacket-$BRO_VERSION.tar.gz *
popd
mv ./bro-plugin-afpacket-$BRO_VERSION.tar.gz  /root/rpmbuild/SOURCES/
git clone https://github.com/JonZeolla/metron-bro-plugin-kafka
pushd metron-bro-plugin-kafka
tar czvf ../bro-plugin-kafka-$BRO_VERSION.tar.gz *
popd
mv ./bro-plugin-kafka-$BRO_VERSION.tar.gz /root/rpmbuild/SOURCES/
pushd /root/rpmbuild/SOURCES/
cat /root/rpmbuild/SPECS/bro.spec | grep ^Patch - | awk '{print $2}' | xargs -n 1 curl -L -O
popd
sed -i -e "s/bro-2.5/bro-$BRO_VERSION/g" /root/rpmbuild/SOURCES/bro-findkernelheaders-hack.patch
rpmbuild -ba /root/rpmbuild/SPECS/bro.spec --with afpacket
mv /root/rpmbuild/RPMS/x86_64/*.rpm ./rpm/bro
rm -f ./rpm/bro/bro-plugin-kafka-$BRO_VERSION-1.el7.centos.x86_64.rpm
yum -y install --downloadonly --downloaddir=./rpm/bro ./rpm/bro/*.rpm

# Suricata
pushd /etc/yum.repos.d
curl -O https://copr.fedorainfracloud.org/coprs/jasonish/suricata-stable/repo/epel-7/jasonish-suricata-stable-epel-7.repo
popd
yum -y install --downloadonly --downloaddir=./rpm/suricata suricata

# Stenographer
rm -rf /root/rpmbuild/BUILD/*
rm -rf /root/rpmbuild/BUILDROOT/*
rm -rf /root/rpmbuild/SOURCES/*
yum -y install --downloadonly --downloaddir=./rpm/stenographer libaio-devel leveldb-devel snappy-devel gcc-c++ make libpcap-devel libseccomp-devel git golang libaio leveldb snappy libpcap libseccomp tcpdump curl rpmlib jq systemd
yum -y localinstall ./rpm/stenographer/*.rpm
curl -L -o ./tar/stenographer/844b5a4e538b4a560550b227c28ac911833713dd.tar.gz https://github.com/google/stenographer/archive/844b5a4e538b4a560550b227c28ac911833713dd.tar.gz
mv ./tar/stenographer/844b5a4e538b4a560550b227c28ac911833713dd.tar.gz /root/rpmbuild/SOURCES/stenographer-844b5a4e538b4a560550b227c28ac911833713dd.tar.gz
mv ./rpmbuild/SPECS/stenographer.spec /root/rpmbuild/SPECS/stenographer.spec
rpmbuild -ba /root/rpmbuild/SPECS/stenographer.spec
mv /root/rpmbuild/RPMS/x86_64/stenographer-*.rpm ./rpm/stenographer

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

# ElasticSearch
docker pull docker.elastic.co/elasticsearch/elasticsearch:$ELASTIC_VERSION
docker tag docker.elastic.co/elasticsearch/elasticsearch:$ELASTIC_VERSION elasticsearch
docker save -o ./images/elasticsearch.docker elasticsearch

# Logstash
docker pull docker.elastic.co/logstash/logstash:$ELASTIC_VERSION
docker tag docker.elastic.co/logstash/logstash:$ELASTIC_VERSION logstash
docker save -o ./images/logstash.docker logstash

# Kibana
docker pull docker.elastic.co/kibana/kibana:$ELASTIC_VERSION
docker tag docker.elastic.co/kibana/kibana:$ELASTIC_VERSION kibana
docker save -o ./images/kibana.docker kibana

# Splunk
docker pull splunk/splunk
docker tag splunk/splunk splunk
docker save -o ./images/splunk.docker splunk

# Universal Splunk Forwarder
docker pull splunk/universalforwarder
docker tag splunk/universalforwarder universalforwarder
docker save -o ./images/universalforwarder.docker universalforwarder

# BusyBox for Splunk
docker pull busybox
docker save -o ./images/busybox.docker busybox

# FreeIPA
docker pull adelton/freeipa-server:centos-7
docker tag adelton/freeipa-server:centos-7 freeipa
docker save -o ./images/freeipa.docker freeipa

# MongoDB for RocketChat
docker pull mongo
docker save -o ./images/mongo.docker mongo

# RocketChat
docker pull rocketchat/rocket.chat
docker tag rocketchat/rocket.chat rocketchat
docker save -o ./images/rocketchat.docker rocketchat

# Nginx
docker pull nginx
docker save -o ./images/nginx.docker nginx

# OwnCloud - Old Version
docker pull owncloud:9.1.6
docker tag owncloud:9.1.6 owncloudbackup
docker save -o ./images/owncloudbackup.docker owncloudbackup

# OwnCloud
docker pull owncloud:latest
docker tag owncloud:latest owncloud
docker save -o ./images/owncloud.docker owncloud

# TheHive
docker pull certbdf/thehive
docker tag certbdf/thehive thehive
docker save -o ./images/thehive.docker thehive

# Cortex for TheHive
docker pull certbdf/cortex
docker tag certbdf/cortex cortex
docker save -o ./images/cortex cortex

# DokuWiki
docker pull mprasil/dokuwiki
docker tag mprasil/dokuwiki dokuwiki
docker save -o ./images/dokuwiki.docker dokuwiki

# Etherpad
docker pull tvelocity/etherpad-lite
docker tag tvelocity/etherpad-lite etherpad
docker save -o ./images/etherpad.docker etherpad

# FSF
docker pull jeffgeiger/centos-fsf
docker tag jeffgeiger/centos-fsf fsf
docker save -o ./images/fsf.docker fsf

################################################################################
# Big Files
################################################################################
curl -L -o ./suricata/rules/emerging-all.rules https://rules.emergingthreats.net/open/snort-2.9.0/emerging-all.rules
curl -L -o ./logstash/GeoLite2-City.tar.gz http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz

################################################################################
# Cleanup
################################################################################

rm -rf bro-af_packet-plugin
rm -rf rpmbuild
rm -rf *.tar.gz
rm -rf metron-bro-plugin-kafka
rm -rf tar
rm -rf /tmp/*.yumtx
