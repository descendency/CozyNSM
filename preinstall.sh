################################################################################
# Choose Versions (everything else will be 'latest' builds)
################################################################################
ELASTIC_VERSION=7.2.0
SPLUNK_VERSION=7.3.0
CORTEX_VERSION=2.1.3
THEHIVE_VERSION=3.2.1
#IS_RHEL="false"
################################################################################
# Prepare the directories
################################################################################
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi
echo "Starting TUI. Please Wait."
mkdir -p ./rpm/updates
mkdir -p ./rpm/extras
mkdir -p ./images
mkdir -p ./tar/bro
mkdir -p ./tar/stenographer
mkdir -p ./rpm/docker
mkdir -p ./rpm/ipa-client
mkdir -p ./rpm/filebeat
mkdir -p ./rpm/moloch
mkdir -p ./rpm/stenographer
mkdir -p ./moloch
mkdir -p ./suricata/rules

{
yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/dialog dialog
yum --nogpgcheck -y -q -e 0 install dialog
} > /dev/null 2>&1

source scripts/preinstall_tui.sh
clear
echo "Starting Downloads..."
#read -p "Domain? " DOMAIN
#if (($(hostname | grep -o "\." | wc -l) > 1)); then DOMAIN=$(echo `hostname` | sed 's/^[^\.]*\.//g'); else read -p "Domain? " DOMAIN; fi
#echo -e "\n!!You must enter the exact same admin password during install!!"
#read -p "Admin Password? " PASSWORD

################################################################################
# RPMs
################################################################################
# Install Repos here.
mv repo/cozy.repo /etc/yum.repos.d
if $IS_RHEL; then
    subscription-manager repos --enable=rhel-7-server-rpms
    subscription-manager repos --enable=rhel-7-server-extras-rpms
    subscription-manager repos --enable=rhel-7-server-supplementary-rpms
    subscription-manager repos --enable=rhel-7-server-optional-rpms
fi
if ! $IS_RHEL; then
    sed -e "s/^gpgcheck=./& \nexclude=applydeltarpm*/" -i /etc/yum.conf
fi
sed -e "s/repo_gpgcheck=1/repo_gpgcheck=0/g" -e "s/localpkg_gpgcheck=1/localpkg_gpgcheck=0/g" -i /etc/yum.conf
yum clean all

# Updates
yum --nogpgcheck -y -q -e 0 update --downloadonly --downloaddir=./rpm/updates
yum clean all

# Dialog
yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/dialog dialog
KERNEL_VERSION=$(if $IS_RHEL; then echo "-ml"; else echo ""; fi)
# Extras
yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/extras ntp git wget rng-tools yum-utils createrepo vim-common dos2unix
yum --nogpgcheck -y -q -e 0 install ntp git wget rng-tools yum-utils vim-common dos2unix
systemctl restart ntpd
curl -L -o ./rpm/extras/epel-release-7-11.noarch.rpm -O http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-11.noarch.rpm
rpm --import http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7
yum --nogpgcheck -y -q -e 0 install ./rpm/extras/epel-release-7-11.noarch.rpm
yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/extras rpm-build elfutils-libelf rpm rpm-libs rpm-python kernel$KERNEL_VERSION kernel$KERNEL_VERSION-devel
yum --nogpgcheck -y -q -e 0 install rpm-build elfutils-libelf rpm rpm-libs rpm-python

# Stenographer
yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/stenographer stenographer #libgudev1 libaio-devel leveldb-devel snappy-devel gcc-c++ make libpcap-devel libseccomp-devel git golang libaio leveldb snappy libpcap libseccomp tcpdump curl rpmlib jq systemd mock rpm-build
yum --nogpgcheck -y -q -e 0 reinstall --downloadonly --downloaddir=./rpm/stenographer python-backports-ssl_match_hostname python-backports

# Docker
yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/docker yum-utils device-mapper-persistent-data lvm2
yum --nogpgcheck -y -q -e 0 install yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/docker docker-ce
yum --nogpgcheck -y -q -e 0 install docker-ce
# Start Docker Service
systemctl start docker

# IPA-client
yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/ipa-client ipa-client nss-pam-ldapd nscd
yum --nogpgcheck -y -q -e 0 reinstall --downloadonly --downloaddir=./rpm/ipa-client python-backports-ssl_match_hostname python-backports

# FileBeat
curl -L -o ./rpm/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm
yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/filebeat ./rpm/filebeat/filebeat-$ELASTIC_VERSION-x86_64.rpm

# Bro
#yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/bro bind-devel bison cmake flex GeoIP-devel gcc-c++ gperftools-devel jemalloc-devel libpcap-devel openssl-devel python2-devel python-tools swig zlib-devel python-devel kernel$KERNEL_VERSION librdkafka-devel
#yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/bro bind-devel bison cmake flex GeoIP-devel gcc-c++ gperftools-devel jemalloc-devel libpcap-devel openssl-devel python2-devel python-tools swig zlib-devel python-devel kernel kernel-devel kernel-headers librdkafka-devel
yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/bro bro bro-aux bro-core bro-plugin-af_packet bro-plugin-kafka broctl

# Suricata
yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/suricata suricata

# Moloch
yum --nogpgcheck -y -q -e 0 install --downloadonly --downloaddir=./rpm/moloch wget curl pcre pcre-devel pkgconfig flex bison gcc-c++ zlib-devel e2fsprogs-devel openssl-devel file-devel make gettext libuuid-devel perl-JSON bzip2-libs bzip2-devel perl-libwww-perl libpng-devel xz libffi-devel readline-devel libtool libyaml-devel perl-Socket6 perl-Test-Differences
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

VAR=$(if $IS_RHEL; then echo "-redhat"; else echo ""; fi)
# Splunk
docker pull splunk/splunk:$SPLUNK_VERSION$VAR
docker tag splunk/splunk:$SPLUNK_VERSION$VAR splunk
docker save -o ./images/splunk.docker splunk
docker rmi splunk/splunk:$SPLUNK_VERSION$VAR

# Universal Splunk Forwarder
docker pull splunk/universalforwarder:$SPLUNK_VERSION$VAR
docker tag splunk/universalforwarder:$SPLUNK_VERSION$VAR universalforwarder
docker save -o ./images/universalforwarder.docker universalforwarder
docker rmi splunk/universalforwarder:$SPLUNK_VERSION$VAR

# BusyBox for Splunk
docker pull busybox
docker save -o ./images/busybox.docker busybox

# FreeIPA
docker pull freeipa/freeipa-server:centos-7
docker tag freeipa/freeipa-server:centos-7 freeipa
docker save -o ./images/freeipa.docker freeipa
docker rmi freeipa/freeipa-server:centos-7

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
docker pull docker.elastic.co/elasticsearch/elasticsearch:5.6.16
docker tag docker.elastic.co/elasticsearch/elasticsearch:5.6.16 eshive
docker save -o ./images/eshive.docker eshive
docker rmi docker.elastic.co/elasticsearch/elasticsearch:5.6.16

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

tar -czv --remove-files -f install-$(date '+%Y%b%d' | awk '{print toupper($0)}').tar.gz *

dialog --backtitle "CozyStack Pre-Install" \
--title "About" \
--msgbox 'Pre-Installation Complete.' 10 30
clear
