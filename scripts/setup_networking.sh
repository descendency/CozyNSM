# Firewalld is currently broken with docker. Until the issue is fixed, it must
# be turned off.
systemctl disable firewalld
systemctl stop firewalld

# Ensure FreeIPA is the default DNS server.
if grep -q DNS1 /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE; then
   sed -e "s@DNS1=\\"?.*\\"?@DNS1=\"$IPA_IP\"@g" -i /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE
else
    echo -e "\nDNS1=\"$IPA_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE
fi
systemctl restart network

# Points the server to its proper DNS server (FreeIPA).
echo -e "\nnameserver $IPA_IP\n" >> /etc/resolv.conf

# Allow IPA admins to sudo.
echo -e "%admins ALL=(ALL)\tALL\n" >> /etc/sudoers
