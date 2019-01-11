# Temporarily disable the local GPG requirement (DISA STIG)
# Enabled at the end of the script.
sed -e "s/repo_gpgcheck=1/repo_gpgcheck=0/g" -e "s/localpkg_gpgcheck=1/localpkg_gpgcheck=0/g" -i /etc/yum.conf
yum clean all
# Locally installs required RPMs for every application.
mkdir /tmp/backup
mv /etc/yum.repos.d/* /tmp/backup
yum -y -q -e 0 localinstall rpm/updates/*.rpm
yum -y -q -e 0 localinstall rpm/extras/*.rpm
if ! (rpm -qa | grep docker 2>&1 > /dev/null); then
    yum -y -q -e 0 localinstall rpm/docker/*.rpm
fi
if ! (rpm -qa | grep ipa-client 2>&1 > /dev/null); then
    yum -y -q -e 0 localinstall rpm/ipa-client/*.rpm
fi
if ! (rpm -qa | grep filebeat 2>&1 > /dev/null); then
    yum -y -q -e 0 localinstall rpm/filebeat/*.rpm
fi
if ! (rpm -qa | grep bro 2>&1 > /dev/null); then
    yum -y -q -e 0 localinstall rpm/bro/*.rpm
fi
if ! (rpm -qa | grep suricata 2>&1 > /dev/null); then
    yum -y -q -e 0 localinstall rpm/suricata/*.rpm
fi
if ! (rpm -qa | grep stenographer 2>&1 > /dev/null); then
    yum -y -q -e 0 localinstall rpm/stenographer/*.rpm
fi
mv /tmp/backup/* /etc/yum.repos.d

# Re-enable the local GPG requirement (DISA STIG)
# Disabled from above.
sed -e "s/repo_gpgcheck=0/repo_gpgcheck=1/g" -e "s/localpkg_gpgcheck=0/localpkg_gpgcheck=1/g" -i /etc/yum.conf
yum clean all
