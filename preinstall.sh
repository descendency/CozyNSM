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
sed -e "s/repo_gpgcheck=1/repo_gpgcheck=0/g" -e "s/localpkg_gpgcheck=1/localpkg_gpgcheck=0/g" -i /etc/yum.conf
yum clean all
# Updates
yum -y update --downloadonly --downloaddir=./rpm/updates
# These break the network connection for some reason.
#rm -rf ./rpm/updates/NetworkManager*

# Extras
yum -y install --downloadonly --downloaddir=./rpm/extras git wget rng-tools
yum -y install git wget rng-tools
curl -L -o ./rpm/extras/epel-release-7-11.noarch.rpm -O http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-11.noarch.rpm
rpm --import http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7
yum -y install ./rpm/extras/epel-release-7-11.noarch.rpm
yum -y install --downloadonly --downloaddir=./rpm/extras rpm-build elfutils-libelf rpm rpm-libs rpm-python
yum -y install rpm-build elfutils-libelf rpm rpm-libs rpm-python

# Docker
yum -y install --downloadonly --downloaddir=./rpm/docker yum-utils device-mapper-persistent-data lvm2
yum -y install yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum -y install --downloadonly --downloaddir=./rpm/docker docker-ce
yum -y install docker-ce
# Start Docker Service
systemctl start docker

# IPA-client
yum -y install --downloadonly --downloaddir=./rpm/ipa-client ipa-client

# FileBeat
curl -L -o ./rpm/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm
yum -y install --downloadonly --downloaddir=./rpm/filebeat ./rpm/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm

# Bro
yum -y install --downloadonly --downloaddir=./rpm/bro bind-devel bison cmake flex GeoIP-devel gcc-c++ gperftools-devel jemalloc-devel libpcap-devel openssl-devel python2-devel python-tools swig zlib-devel python-devel kernel-devel kernel-headers librdkafka-devel
yum -y install bind-devel bison cmake flex GeoIP-devel gcc-c++ gperftools-devel jemalloc-devel libpcap-devel openssl-devel python2-devel python-tools swig zlib-devel python-devel kernel-devel kernel-headers librdkafka-devel
curl -L -o ./tar/bro/bro-$BRO_VERSION.tar.gz -O https://www.bro.org/downloads/bro-$BRO_VERSION.tar.gz
mv ./tar/bro/bro-$BRO_VERSION.tar.gz  /root/rpmbuild/SOURCES/
git clone https://github.com/dcode/rpmbuild.git
sed -i -e "s@--strip-components=1@@g" -e "s@%{_libdir}/broctl/*\.p*@@" -e "s@%files -n broctl@%files -n broctl"$'\\\n'"%exclude %{_libdir}/broctl/broccoli*.p*"$'\\\n'"%exclude %{_libdir}/broctl/_broccoli_intern.so@g" -e "s/APACHE_KAFKA/BRO_KAFKA/g" ./rpmbuild/SPECS/bro.spec
sed -i -e '/%dir %{_libdir}\/bro\/plugins\/BRO_KAFKA\/scripts\/Apache/d' -e '/%dir %{_libdir}\/bro\/plugins\/BRO_KAFKA\/scripts\/Apache\/Kafka/d' -e '/%{_libdir}\/bro\/plugins\/BRO_KAFKA\/scripts\/Apache\/Kafka\/\*.bro/d' ./rpmbuild/SPECS/bro.spec
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
yum -y install libaio-devel leveldb-devel snappy-devel gcc-c++ make libpcap-devel libseccomp-devel git golang libaio leveldb snappy libpcap libseccomp tcpdump curl rpmlib jq systemd
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
docker pull docker.elastic.co/elasticsearch/elasticsearch-platinum:$ELASTIC_VERSION
docker tag docker.elastic.co/elasticsearch/elasticsearch-platinum:$ELASTIC_VERSION elasticsearch
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
#
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

# OwnCloud
docker pull owncloud:latest
docker tag owncloud:latest owncloud
docker save -o ./images/owncloud.docker owncloud

# TheHive
docker pull certbdf/thehive:2.13.2-1
docker tag certbdf/thehive:2.13.2-1 thehive
docker save -o ./images/thehive.docker thehive

# Cortex for TheHive
docker pull certbdf/cortex
docker tag certbdf/cortex cortex
docker save -o ./images/cortex.docker cortex

# DokuWiki
docker pull mprasil/dokuwiki
docker tag mprasil/dokuwiki dokuwiki
docker save -o ./images/dokuwiki.docker dokuwiki

# Etherpad
docker pull tvelocity/etherpad-lite
docker tag tvelocity/etherpad-lite etherpad
docker save -o ./images/etherpad.docker etherpad

# FSF
docker pull wzod/fsf
docker tag wzod/fsf fsf
docker save -o ./images/fsf.docker fsf

# Kafka
docker pull wurstmeister/kafka
docker tag wurstmeister/kafka kafka
docker save -o ./images/kafka.docker kafka

################################################################################
# Big Files
################################################################################
curl -L -o ./suricata/rules/emerging-all.rules https://rules.emergingthreats.net/open/snort-2.9.0/emerging-all.rules
curl -L -o ./logstash/GeoLite2-City.tar.gz http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz

################################################################################
# Elastic Certificates
################################################################################
sysctl -w vm.max_map_count=1073741824
docker run --restart=always -itd --name es -e ELASTIC_PASSWORD=changeme elasticsearch
#docker cp elasticsearch/instances.yml es:/usr/share/elasticsearch/instances.yml
docker cp elasticsearch/instances.yml es:/usr/share/elasticsearch/config/x-pack/instances.yml
echo certs.zip | docker exec -iu root es /usr/share/elasticsearch/bin/x-pack/certgen --in instances.yml
mkdir certs
#docker cp es:/usr/share/elasticsearch/certs.zip certs/certs.zip
docker cp es:/usr/share/elasticsearch/config/x-pack/certs.zip certs/certs.zip
unzip certs/certs.zip -d certs
docker rm -f -v es

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
