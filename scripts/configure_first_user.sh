################################################################################
# CONFIGURE: First User/Admin                                                  #
################################################################################
# Create new admin's home directory
if ! [[ -d /home/$IPA_USERNAME ]]; then
    cp -R /etc/skel /home
    mv /home/skel /home/$IPA_USERNAME
    chown -R $IPA_USERNAME:$IPA_USERNAME /home/$IPA_USERNAME
fi


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

# Remove root access
sed -e 's/^#PermitRootLogin yes$/PermitRootLogin no/g' -i /etc/ssh/sshd_config
sed -e 's@^\(root.*\)/bin/bash$@\1/sbin/nologin@g' -i /etc/passwd
