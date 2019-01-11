################################################################################
# CONFIGURE: First User/Admin                                                  #
################################################################################
# Create new admin's home directory
if ! [[ -d /home/$IPA_USERNAME ]]; then
    cp -R /etc/skel /home
    mv /home/skel /home/$IPA_USERNAME
    chown -R $IPA_USERNAME:$IPA_USERNAME /home/$IPA_USERNAME
fi

setenforce 0
HOSTNAME=""
if (($(hostname | grep -o "\." | wc -l) > 1)); then HOSTNAME=$(hostname); else HOSTNAME=$(hostname).$DOMAIN; fi
# Configure IPA client -- Nothing bad happens if this is tried twice, so I won't check to see if it's setup.
ipa-client-install -U --server=ipa.$DOMAIN \
                    --domain=$DOMAIN \
                    -p admin \
                    -w $IPA_ADMIN_PASSWORD \
                    --mkhomedir \
                    --hostname $HOSTNAME \
                    --ntp-server=ipa.$DOMAIN
setenforce Enforcing
chown root:root /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf
sed -i -e 's/services = sudo, pam, autofs, ssh/services = sudo, pam, autofs, ssh, nss/' /etc/sssd/sssd.conf
systemctl restart sssd
# edit /etc/nslcd.conf to add ipa configuration...
sed -i -e "s@uri ldap://127.0.0.1/@uri ldap://ipa.$DOMAIN/@" /etc/nslcd.conf
sed -i -e "s@base dc=example,dc=com@base cn=users,cn=accounts,dc=${DOMAIN//\./,dc=}@" /etc/nslcd.conf
sed -i -e "s@#binddn cn=proxyuser,dc=example,dc=com@binddn uid=$IPA_USERNAME,cn=users,cn=accounts,dc=${DOMAIN//\./,dc=}@" /etc/nslcd.conf
sed -i -e "s@#bindpw secret@bindpw $IPA_ADMIN_PASSWORD@" /etc/nslcd.conf
systemctl restart nslcd
systemctl enable nslcd

# Remove root access
sed -e 's/^#PermitRootLogin yes$/PermitRootLogin no/g' -i /etc/ssh/sshd_config
sed -e 's@^\(root.*\)/bin/bash$@\1/sbin/nologin@g' -i /etc/passwd
