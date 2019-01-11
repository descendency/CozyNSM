################################################################################
# Choose Versions (everything else will be 'latest' builds)
################################################################################
ELASTIC_VERSION=6.5.4
BRO_VERSION=2.6.1
SPLUNK_VERSION=7.2.3
CORTEX_VERSION=2.1.3
THEHIVE_VERSION=3.2.1
#read -p "Domain? " DOMAIN
if (($(hostname | grep -o "\." | wc -l) > 1)); then DOMAIN=$(echo `hostname` | sed 's/^[^\.]*\.//g'); else read -p "Domain? " DOMAIN; fi
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
# Updates
yum -y -q -e 0 update --downloadonly --downloaddir=./rpm/updates
# These break the network connection for some reason.
#rm -rf ./rpm/updates/NetworkManager*

# Extras
yum -y -q -e 0 install --downloadonly --downloaddir=./rpm/extras ntp git wget rng-tools createrepo vim-common dos2unix
yum -y -q -e 0 install ntp git wget rng-tools createrepo vim-common dos2unix
systemctl restart ntpd
curl -L -o ./rpm/extras/epel-release-7-11.noarch.rpm -O http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-11.noarch.rpm
rpm --import http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7
yum -y -q -e 0 install ./rpm/extras/epel-release-7-11.noarch.rpm
yum -y -q -e 0 install --downloadonly --downloaddir=./rpm/extras rpm-build elfutils-libelf rpm rpm-libs rpm-python
yum -y -q -e 0 install rpm-build elfutils-libelf rpm rpm-libs rpm-python

# Stenographer
yum -y -q -e 0 install --downloadonly --downloaddir=./rpm/stenographer libaio-devel leveldb-devel snappy-devel gcc-c++ make libpcap-devel libseccomp-devel git golang libaio leveldb snappy libpcap libseccomp tcpdump curl rpmlib jq systemd mock rpm-build
#yum -y install libaio-devel leveldb-devel snappy-devel gcc-c++ make libpcap-devel libseccomp-devel git golang libaio leveldb snappy libpcap libseccomp tcpdump curl rpmlib jq systemd mock rpm-build
#TMPDIR=$(mktemp -d)
#pushd $TMPDIR
#git clone https://github.com/google/stenographer
#pushd stenographer
#chmod +x rpmbuild-steno-centos
#./rpmbuild-steno-centos
#popd
#popd
#rm -rf $TMPDIR
#mv /var/lib/mock/epel-7-x86_64/result/stenographer*.x86_64.rpm rpm/stenographer

# Docker
yum -y -q -e 0 install --downloadonly --downloaddir=./rpm/docker yum-utils device-mapper-persistent-data lvm2
yum -y -q -e 0 install yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum -y -q -e 0 install --downloadonly --downloaddir=./rpm/docker docker-ce
yum -y -q -e 0 install docker-ce
# Start Docker Service
systemctl start docker

# IPA-client
yum -y -q -e 0 install --downloadonly --downloaddir=./rpm/ipa-client ipa-client nss-pam-ldapd nscd

# FileBeat
curl -L -o ./rpm/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm
yum -y -q -e 0 install --downloadonly --downloaddir=./rpm/filebeat ./rpm/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm

# Bro
yum -y -q -e 0 install --downloadonly --downloaddir=./rpm/bro bind-devel bison cmake flex GeoIP-devel gcc-c++ gperftools-devel jemalloc-devel libpcap-devel openssl-devel python2-devel python-tools swig zlib-devel python-devel kernel-devel kernel-headers librdkafka-devel
#yum -y install bind-devel bison cmake flex GeoIP-devel gcc-c++ gperftools-devel jemalloc-devel libpcap-devel openssl-devel python2-devel python-tools swig zlib-devel python-devel kernel-devel kernel-headers librdkafka-devel
curl -L -o ./bro/bro-$BRO_VERSION.tar.gz -O https://www.bro.org/downloads/bro-$BRO_VERSION.tar.gz
git clone https://github.com/J-Gras/bro-af_packet-plugin
tar czvf bro/bro-af_packet-plugin.tar.gz bro-af_packet-plugin
#mv ./tar/bro/bro-$BRO_VERSION.tar.gz  /root/rpmbuild/SOURCES/
#git clone https://github.com/dcode/rpmbuild.git
#sed -i -e "s@--strip-components=1@@g" -e "s@%{_libdir}/broctl/*\.p*@@" -e "s@%files -n broctl@%files -n broctl"$'\\\n'"%exclude %{_libdir}/broctl/broccoli*.p*"$'\\\n'"%exclude %{_libdir}/broctl/_broccoli_intern.so@g" -e "s/APACHE_KAFKA/BRO_KAFKA/g" ./rpmbuild/SPECS/bro.spec
#sed -i -e '/%dir %{_libdir}\/bro\/plugins\/BRO_KAFKA\/scripts\/Apache/d' -e '/%dir %{_libdir}\/bro\/plugins\/BRO_KAFKA\/scripts\/Apache\/Kafka/d' -e '/%{_libdir}\/bro\/plugins\/BRO_KAFKA\/scripts\/Apache\/Kafka\/\*.bro/d' ./rpmbuild/SPECS/bro.spec
#mv ./rpmbuild/SPECS/bro.spec /root/rpmbuild/SPECS/bro.spec
#pushd ./bro-af_packet-plugin
#tar czvf ../bro-plugin-afpacket-$BRO_VERSION.tar.gz *
#popd
#mv ./bro-plugin-afpacket-$BRO_VERSION.tar.gz  /root/rpmbuild/SOURCES/
#git clone https://github.com/JonZeolla/metron-bro-plugin-kafka
#pushd metron-bro-plugin-kafka
#tar czvf ../bro-plugin-kafka-$BRO_VERSION.tar.gz *
#popd
#mv ./bro-plugin-kafka-$BRO_VERSION.tar.gz /root/rpmbuild/SOURCES/
#pushd /root/rpmbuild/SOURCES/
#cat /root/rpmbuild/SPECS/bro.spec | grep ^Patch - | awk '{print $2}' | xargs -n 1 curl -L -O
#popd
#sed -i -e "s/bro-2.5/bro-$BRO_VERSION/g" /root/rpmbuild/SOURCES/bro-findkernelheaders-hack.patch
#rpmbuild -ba /root/rpmbuild/SPECS/bro.spec
#mv /root/rpmbuild/RPMS/x86_64/*.rpm ./rpm/bro
#rm -f ./rpm/bro/bro-plugin-kafka-$BRO_VERSION-1.el7.centos.x86_64.rpm
#yum -y install --downloadonly --downloaddir=./rpm/bro ./rpm/bro/*.rpm

# Suricata
pushd /etc/yum.repos.d
curl -O https://copr.fedorainfracloud.org/coprs/jasonish/suricata-stable/repo/epel-7/jasonish-suricata-stable-epel-7.repo
popd
yum -y -q -e 0 install --downloadonly --downloaddir=./rpm/suricata suricata
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
docker pull thehiveproject/thehive:$THEHIVE_VERSION
docker tag thehiveproject/thehive:$THEHIVE_VERSION thehive
docker save -o ./images/thehive.docker thehive
docker rmi thehiveproject/thehive:$THEHIVE_VERSION

# Cortex for TheHive
docker pull thehiveproject/cortex:$CORTEX_VERSION
docker tag thehiveproject/cortex:$CORTEX_VERSION cortex
docker save -o ./images/cortex.docker cortex
docker rmi thehiveproject/cortex:$CORTEX_VERSION

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
