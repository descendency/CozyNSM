systemctl start firewalld
systemctl enable firewalld

#Add the local network and docker networks to the trusted zones.
firewall-cmd --permanent --zone=trusted --add-source=$IP.0/24
firewall-cmd --permanent --zone=trusted --add-source=172.18.0.0/24
firewall-cmd --permanent --zone=trusted --add-source=172.19.0.0/24
firewall-cmd --permanent --zone=trusted --add-source=172.20.0.0/24
firewall-cmd --reload
# Ensure FreeIPA is the default DNS server.
if grep -q DNS1 /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE; then
   sed -e "s@DNS1=\\"?.*\\"?@DNS1=\"$IPA_IP\"@g" -i /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE
else
    echo -e "\nDNS1=\"$IPA_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE
fi
systemctl restart network

sed -e 's@BOOTPROTO=dhcp@BOOTPROTO=static@' -i /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE
nmcli con mod $ANALYST_INTERFACE ipv4.dns "$IPA_IP"
nmcli c d $ANALYST_INTERFACE
nmcli c u $ANALYST_INTERFACE
sysctl -w net.ipv4.conf.all.forwarding=1
# Points the server to its proper DNS server (FreeIPA).
echo -e "\nnameserver $IPA_IP\n" >> /etc/resolv.conf

# Allow IPA admins to sudo.
echo -e "%admins ALL=(ALL)\tALL\n" >> /etc/sudoers

# Ensure IP Fowarding works.
sed -i -e 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/'  /etc/sysctl.conf
