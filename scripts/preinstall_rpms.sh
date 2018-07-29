if [ -z $BRO_VERSION ]; then
    BRO_VERSION=2.5.4
fi
################################################################################
# Prepare the directories
################################################################################
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

################################################################################
# RPMs
################################################################################

sed -e "s/repo_gpgcheck=1/repo_gpgcheck=0/g" -e "s/localpkg_gpgcheck=1/localpkg_gpgcheck=0/g" -i /etc/yum.conf
yum clean all
# Updates
yum -y -q -e 0 update

# Extras
yum -y -q -e 0 --skip-broken install bind-devel bison cmake curl \
    device-mapper-persistent-data docker-ce elfutils-libelf flex gcc-c++ \
    GeoIP-devel git golang gperftools-devel ipa-client jemalloc-devel jq \
    libpcap kernel-devel kernel-headers leveldb leveldb-devel libaio \
    libaio-devel libpcap-devel librdkafka-devel libseccomp libseccomp-devel \
    lvm2 make mock ntp openssl-devel python-devel python-tools python2-devel \
    rng-tools rpm rpm-build rpm-libs rpm-python rpmlib snappy snappy-devel \
    suricata swig systemd tcpdump wget yum-utils zlib-devel

systemctl restart ntpd

################################################################################
# Cleanup
################################################################################
sed -e "s/repo_gpgcheck=0/repo_gpgcheck=1/g" -i /etc/yum.conf
rm -rf /tmp/*.yumtx
