{
# Temporarily disable the local GPG requirement (DISA STIG)
# Enabled at the end of the script.
sed -e "s/repo_gpgcheck=1/repo_gpgcheck=0/g" -e "s/localpkg_gpgcheck=1/localpkg_gpgcheck=0/g" -i /etc/yum.conf
yum -q -e 0 clean all
# Locally installs required RPMs for every application.
mkdir /tmp/backup
mv /etc/yum.repos.d/* /tmp/backup
yum -y -q -e 0 localinstall rpm/updates/*.rpm
yum -y -q -e 0 localinstall rpm/extras/*.rpm
if ! (rpm -qa | grep docker 2>&1 > /dev/null); then
    yum -y -q -e 0 localinstall rpm/docker/*.rpm
    systemctl enable docker
    mkdir -p /data/docker
    chmod 701 /data/docker
    sed -i -e "s/ExecStart.*/& -g \/data\/docker/" /etc/systemd/system/multi-user.target.wants/docker.service
    systemctl daemon-reload
    systemctl start docker
fi
if ! (rpm -qa | grep ipa-client 2>&1 > /dev/null); then
    yum -y -q -e 0 localinstall rpm/ipa-client/*.rpm
fi
if $IS_SENSOR; then
    if $ENABLE_ELK; then
        yum --nogpgcheck -y -q -e 0 localinstall rpm/filebeat/*.rpm
    fi
    if $ENABLE_BRO; then
        yum --nogpgcheck -y -q -e 0 localinstall rpm/bro/*.rpm
    fi
    if $ENABLE_SURICATA; then
        yum --nogpgcheck -y -q -e 0 localinstall rpm/suricata/*.rpm
    fi
    if $ENABLE_STENOGRAPHER; then
        yum --nogpgcheck -y -q -e 0 localinstall rpm/stenographer/*.rpm
    fi
fi
mv /tmp/backup/* /etc/yum.repos.d

# Re-enable the local GPG requirement (DISA STIG)
# Disabled from above.
sed -e "s/repo_gpgcheck=0/repo_gpgcheck=1/g" -e "s/localpkg_gpgcheck=0/localpkg_gpgcheck=1/g" -i /etc/yum.conf
yum -q -e 0 clean all
} > /dev/null 2>&1
