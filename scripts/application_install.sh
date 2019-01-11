# Automates the sysctl commands below, on boot
echo "net.ipv4.conf.all.forwarding=1" >> /usr/lib/sysctl.d/00-system.conf
echo "vm.max_map_count=1073741824" >> /usr/lib/sysctl.d/00-system.conf

# Routes packets internally for docker
sysctl -w net.ipv4.conf.all.forwarding=1

# Fixes an ElasticSearch issue in 5.x+
sysctl -w vm.max_map_count=1073741824
systemctl restart network

# Generate SSL certs
if [ ! -f nginx/nginx.key ]; then
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout nginx/nginx.key -out nginx/nginx.crt -subj "/C=US/ST=/L=/O=CozyStack/OU=CozyStack/CN=$DOMAIN"
openssl req -out nginx/nginx.csr -key nginx/nginx.key -new -subj "/C=US/ST=/L=/O=CozyStack/OU=CozyStack/CN=$DOMAIN"
cat nginx/nginx.crt nginx/nginx.key > nginx/nginx.pem
fi

################################################################################
# INSTALL: Docker                                                              #
################################################################################
systemctl enable docker
systemctl start docker
systemctl enable rngd
systemctl start rngd

docker network create --driver=bridge --subnet=172.19.0.0/24 --gateway=172.19.0.1 --ipv6 --subnet=2001:3200:3201::/64 --gateway=2001:3200:3201::1 appbridge
################################################################################
# LOAD: Docker Images                                                          #
################################################################################
docker load -q -i ./images/freeipa.docker

if $ENABLE_GOGS; then
    docker load -q -i ./images/gogs.docker
fi
if $ENABLE_OWNCLOUD; then
    docker load -q -i ./images/owncloud.docker
fi
if $ENABLE_CHAT; then
    docker load -q -i ./images/mongo.docker
    docker load -q -i ./images/rocketchat.docker
fi
if $ENABLE_HIVE; then
    docker load -q -i ./images/thehive.docker
    docker load -q -i ./images/eshive.docker
    docker load -q -i ./images/cortex.docker
fi

#docker load -i ./images/fsf.docker
docker load -q -i ./images/nginx.docker
################################################################################
# INSTALL: FreeIPA                                                             #
################################################################################
firewall-cmd --permanent --add-service={ntp,http,https,ldap,ldaps,kerberos,kpasswd,dns}
firewall-cmd --reload
bash scripts/interface.sh $ANALYST_INTERFACE $IPA_IP
mkdir -p /var/lib/ipa-data
echo -e "-U" > /var/lib/ipa-data/ipa-server-install-options
echo -e "-r $DOMAIN" >> /var/lib/ipa-data/ipa-server-install-options
echo -e "-n $DOMAIN" >> /var/lib/ipa-data/ipa-server-install-options
echo -e "-p $IPA_ADMIN_PASSWORD" >> /var/lib/ipa-data/ipa-server-install-options
echo -e "-a $IPA_ADMIN_PASSWORD" >> /var/lib/ipa-data/ipa-server-install-options
echo -e "--mkhomedir" >> /var/lib/ipa-data/ipa-server-install-options
echo -e "--setup-dns" >> /var/lib/ipa-data/ipa-server-install-options
echo -e "--no-forwarders" >> /var/lib/ipa-data/ipa-server-install-options
echo -e "--no-reverse" >> /var/lib/ipa-data/ipa-server-install-options

docker run --name ipa --restart=always -tid -h ipa.$DOMAIN --privileged \
            -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
            -v /dev/urandom:/dev/random:ro \
            --network="appbridge" \
            --ip 172.19.0.253 \
            --ip6="2001:3200:3201::1337" \
            -v /var/lib/ipa-data:/data:Z \
            --tmpfs /run \
            --tmpfs /tmp \
            -e IPA_SERVER_IP=$IPA_IP \
            -p $IPA_IP:53:53/udp \
            -p $IPA_IP:53:53 \
            -p $IPA_IP:80:80 \
            -p $IPA_IP:443:443 \
            -p $IPA_IP:389:389 \
            -p $IPA_IP:636:636 \
            -p $IPA_IP:88:88 \
            -p $IPA_IP:464:464 \
            -p $IPA_IP:88:88/udp \
            -p $IPA_IP:464:464/udp \
            -p $IPA_IP:123:123/udp \
            -p $IPA_IP:7389:7389 \
            -p $IPA_IP:9443:9443 \
            -p $IPA_IP:9444:9444 \
            -p $IPA_IP:9445:9445 \
            freeipa

            sleep 1

            TMPOUT=$(docker logs ipa | tail -1)
            while [[ $TMPOUT != "FreeIPA server configured."* ]];do
                TMPOUT=$(docker logs ipa | tail -1)
                sleep 0.1
            done


# Fixes a memory assignemnt issue I still don't completely understand.
sysctl vm.drop_caches=3


################################################################################
# INSTALL: GoGS                                                                #
################################################################################
if $ENABLE_GOGS; then
    bash scripts/interface.sh $ANALYST_INTERFACE $GOGS_IP
    docker run --restart=always -itd --name gogs -h gogs.$DOMAIN \
                --ip 172.19.0.$(echo $GOGS_IP | awk -F . '{print $4}') \
                --network="appbridge" \
                -p $GOGS_IP:1022:22 \
                gogs

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3
    docker exec -itu root gogs mkdir /app/certs
    docker cp nginx/nginx.key gogs:/app/certs/nginx.key
    docker cp nginx/nginx.crt gogs:/app/certs/nginx.crt
    docker restart gogs
PROXYPORTS=$PROXYPORTS"-p $GOGS_IP:80:80 -p $GOGS_IP:443:443 "
fi
################################################################################
# INSTALL: MongoDB for Rocket.Chat                                             #
################################################################################
if $ENABLE_CHAT; then
    bash scripts/interface.sh $ANALYST_INTERFACE $CHAT_IP
    docker run --name mongodb --restart=always -tid -h mongodb.$DOMAIN \
                --ip 172.19.0.4 \
                --network="appbridge" \
                mongo

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3
################################################################################
# INSTALL: Rocket.Chat                                                         #
################################################################################
    docker run --name chat --restart=always -tid -h chat.$DOMAIN \
                --ip 172.19.0.$(echo $CHAT_IP | awk -F . '{print $4}') \
                --network="appbridge" \
    			-e OVERWRITE_SETTING_LDAP_Authentication="True" \
    			-e OVERWRITE_SETTING_LDAP_Login_Fallback="True" \
    			-e OVERWRITE_SETTING_LDAP_Host="$IPA_IP" \
    			-e OVERWRITE_SETTING_LDAP_Port="389" \
    			-e OVERWRITE_SETTING_LDAP_Connect_Timeout="600000" \
    			-e OVERWRITE_SETTING_LDAP_Idle_Timeout="600000" \
    			-e OVERWRITE_SETTING_LDAP_Encryption="No Encryption" \
    			-e OVERWRITE_SETTING_LDAP_Domain_Base="cn=users,cn=accounts,dc=${DOMAIN//\./,dc=}" \
    			-e OVERWRITE_SETTING_LDAP_Domain_Search_User="uid=admin,cn=users,cn=accounts,dc=${DOMAIN//\./,dc=}" \
    			-e OVERWRITE_SETTING_LDAP_Domain_Search_Password="$IPA_ADMIN_PASSWORD" \
    			-e OVERWRITE_SETTING_LDAP_Domain_Search_Filter="" \
    			-e OVERWRITE_SETTING_LDAP_Domain_Search_User_ID="uid" \
    			-e OVERWRITE_SETTING_LDAP_Domain_Search_Object_Class="" \
    			-e OVERWRITE_SETTING_LDAP_Domain_Search_Object_Category="" \
    			-e OVERWRITE_SETTING_LDAP_Username_Field="" \
    			-e OVERWRITE_SETTING_LDAP_Sync_User_Data="True" \
    			-e OVERWRITE_SETTING_LDAP_Default_Domain="$DOMAIN" \
    			-e OVERWRITE_SETTING_LDAP_Merge_Existing_Users="True" \
    			-e OVERWRITE_SETTING_LDAP_Import_Users="True" \
    			-e ROOT_URL=http://$CHAT_IP \
    			-e MONGO_URL=mongodb://172.19.0.4/mydb \
    			-e ADMIN_USERNAME=localadmin \
    			-e ADMIN_PASS=$IPA_ADMIN_PASSWORD \
    			-e ADMIN_EMAIL=cozyadmin@$DOMAIN \
    			--link mongodb \
                rocketchat

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3
    PROXYPORTS=$PROXYPORTS"-p $CHAT_IP:80:80 -p $CHAT_IP:443:443 "
fi
################################################################################
# INSTALL: OwnCloud                                                            #
################################################################################
if $ENABLE_OWNCLOUD; then
    bash scripts/interface.sh $ANALYST_INTERFACE $OWNCLOUD_IP
    docker run --restart=always -itd --name owncloud -h owncloud.$DOMAIN \
                --ip 172.19.0.$(echo $OWNCLOUD_IP | awk -F . '{print $4}') \
                --network="appbridge" \
                -p $OWNCLOUD_IP:80:80 \
                -p $OWNCLOUD_IP:443:443 \
                owncloud

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3

fi
################################################################################
# INSTALL: ElasticSearch for TheHive                                           #
################################################################################
if $ENABLE_HIVE; then
docker run --restart=always -itd --name eshive -h eshive.$DOMAIN \
    --network="appbridge" \
    --ip 172.19.0.111 \
    -e "xpack.security.enabled=false" \
    -e "cluster.name=hive" \
    -e ELASTIC_PASSWORD=$IPA_ADMIN_PASSWORD \
    eshive

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3

################################################################################
# INSTALL: TheHive                                                             #
################################################################################
bash scripts/interface.sh $ANALYST_INTERFACE $HIVE_IP
docker run --restart=always -itd --name thehive -h hive.$DOMAIN \
    --network="appbridge" \
    --ip 172.19.0.110 \
    thehive --es-hostname 172.19.0.111 --cortex-hostname 172.19.0.112

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3
PROXYPORTS=$PROXYPORTS"-p $HIVE_IP:80:80 -p $HIVE_IP:443:443 "
################################################################################
# INSTALL: Cortex                                                              #
################################################################################
bash scripts/interface.sh $ANALYST_INTERFACE $CORTEX_IP
docker run --restart=always -itd --name cortex -h cortex.$DOMAIN \
    --network="appbridge" \
    --ip 172.19.0.112 \
    cortex

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3

PROXYPORTS=$PROXYPORTS"-p $CORTEX_IP:80:80 -p $CORTEX_IP:443:443 "
fi
################################################################################
# Auto Configure SSO                                                           #
################################################################################

if $ENABLE_GOGS; then
# GoGS
sed -e "s/GOGSDOMAIN/gogs.$DOMAIN/g" -i gogs/app.ini
docker cp gogs/app.ini gogs:/data/gogs/conf/app.ini
sqlite3 gogs/gogs.db "UPDATE user SET lower_name=\"localadmin\", name=\"localadmin\", email=\"dontemailme@$DOMAIN\", avatar_email=\"dontemailme@$DOMAIN\" WHERE id=1;"
sqlite3 gogs/gogs.db "$(sed -e "s/IPA_IP/$IPA_IP/g" -e "s/DOMAIN/dc=${DOMAIN//\./,dc=}/g" -e "s/ADMIN_PASSWORD/$IPA_ADMIN_PASSWORD/g" gogs/test.txt)"
docker cp gogs/gogs.db gogs:/app/gogs/data/gogs.db
docker exec -itu root gogs chmod a+w /app/gogs/data/gogs.db
docker exec -itu root gogs chmod a+w /data/gogs/data
docker restart gogs
fi

if $ENABLE_OWNCLOUD; then
# OwnCloud
docker exec -itu root owncloud a2enmod ssl
sed -e "s/DOMAINNAME/cloud.$DOMAIN/g" -i owncloud/000-default.conf
docker exec -itu root owncloud chmod a+w /var/www/html
docker cp owncloud/000-default.conf owncloud:/etc/apache2/sites-available/000-default.conf
docker cp owncloud/user_ldap-0.9.1.tar.gz owncloud:/var/www/html/apps/user_ldap-0.9.1.tar.gz
docker exec -itu www-data owncloud tar xzvf /var/www/html/apps/user_ldap-0.9.1.tar.gz -C /var/www/html/apps
docker exec -itu root owncloud chown www-data:nogroup -R /var/www/html/apps/
docker cp nginx/nginx.crt owncloud:/etc/ssl/certs/nginx.crt
docker cp nginx/nginx.key owncloud:/etc/ssl/certs/nginx.key
docker exec -itu www-data owncloud php occ maintenance:install --database="sqlite" --database-name="owncloud" --database-table-prefix="oc_" --admin-user "localadmin" --admin-pass "$IPA_ADMIN_PASSWORD"
docker exec -itu www-data owncloud php occ app:enable user_ldap
docker exec -itu www-data owncloud php occ ldap:create-empty-config
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapHost "$IPA_IP"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapPort "389"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapAgentName "uid=admin,cn=users,cn=accounts,dc=${DOMAIN//\./,dc=}"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapAgentPassword "$IPA_ADMIN_PASSWORD"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapBase "cn=users,cn=accounts,dc=${DOMAIN//\./,dc=}"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapBaseGroups "cn=groups,cn=accounts,dc=${DOMAIN//\./,dc=}"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapBaseGroups "cn=users,cn=accounts,dc=${DOMAIN//\./,dc=}"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapEmailAttribute "mail"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapExpertUsernameAttr "cn"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapGroupFilterObjectclass "ipausergroup"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapGroupMemberAssocAttr "member"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapUserDisplayName "cn"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapUserDisplayName2 "mail"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapUserFilterObjectclass "posixaccount"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapUserFilter "(|(objectclass=person))"
docker exec -itu www-data owncloud php occ ldap:set-config s01 ldapLoginFilter "(&(|(objectclass=person))(uid=%uid))"
docker exec -itu www-data owncloud php occ config:system:set trusted_domains 2 --value=cloud.$DOMAIN
docker restart owncloud
fi

# TheHive
if $ENABLE_HIVE; then
    sed -i -e "s/IPAADMINUSER/$IPA_USERNAME/g" -e "s/IPAIP/$IPA_IP/g" -e "s/IPA_ADMIN_PASSWORD/$IPA_ADMIN_PASSWORD/g" -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" thehive/application.conf
    docker cp thehive/application.conf thehive:/etc/thehive/application.conf
    docker restart thehive

    sed -i -e "s/IPAADMINUSER/$IPA_USERNAME/g" -e "s/IPAIP/$IPA_IP/g" -e "s/IPA_ADMIN_PASSWORD/$IPA_ADMIN_PASSWORD/g" -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" cortex/application.conf
    docker cp cortex/application.conf cortex:/etc/cortex/application.conf
    docker restart cortex
fi

################################################################################
# INSTALL: DokuWiki                                                            #
################################################################################
#
################################################################################
# INSTALL: NGINX Reverse Proxy                                                 #
################################################################################
# Create the reverse proxy
docker run --restart=always -itd --name appproxy -h appproxy.$DOMAIN \
            --ip 172.19.0.51 \
            --network="appbridge" \
            $(echo $PROXYPORTS) \
            nginx

# Copy SSL Certs into directories
docker exec -itu root appproxy mkdir /etc/nginx/ssl
docker cp nginx/nginx.key appproxy:/etc/nginx/ssl/nginx.key
docker cp nginx/nginx.crt appproxy:/etc/nginx/ssl/nginx.crt

### Modify the configuration
sed -e "s/DOMAIN/$DOMAIN/g" \
    -e "s/GOGSIP/172.19.0.$(echo $GOGS_IP | awk -F . '{print $4}')/g" \
    -e "s/OWNCLOUDIP/172.19.0.$(echo $OWNCLOUD_IP | awk -F . '{print $4}')/g" \
    -e "s/CHATIP/172.19.0.$(echo $CHAT_IP | awk -F . '{print $4}')/g" \
    -e "s/KIBANAIP/172.18.0.$(echo $KIBANA_IP | awk -F . '{print $4}')/g" \
    -e "s/SPLUNKIP/172.18.0.$(echo $SPLUNK_IP | awk -F . '{print $4}')/g" \
    -e "s/HIVEIP/172.19.0.110/g" \
    -e "s/CORTEXIP/172.19.0.112/g" \
    -i nginx/nginx.conf
docker cp nginx/nginx.conf appproxy:/etc/nginx/nginx.conf

# Start Reverse Proxy
docker restart appproxy

################################################################################
# CONFIGURE: DNS                                                               #
################################################################################
# Sign in as IPA admin
echo $IPA_ADMIN_PASSWORD | docker exec -iu root ipa kinit admin


# Create DNS A-Records
docker exec -iu root ipa ipa dnsrecord-add $DOMAIN ipa --a-rec=$IPA_IP
docker exec -iu root ipa ipa dnsrecord-add $DOMAIN ipa-ca --a-rec=$IPA_IP

if $ENABLE_ELK; then
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN elasticsearch --a-rec=192.168.1.$(echo $ES_IP | awk -F . '{print $4}')
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN es --a-rec=192.168.1.$(echo $ES_IP | awk -F . '{print $4}')
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN essearch --a-rec=192.168.1.$(echo $ESSEARCH_IP | awk -F . '{print $4}')
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN logstash --a-rec=$ES_IP
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN kibana --a-rec=$KIBANA_IP
fi

if $ENABLE_OWNCLOUD; then
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN owncloud --a-rec=$OWNCLOUD_IP
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN cloud --a-rec=$OWNCLOUD_IP
fi

if $ENABLE_GOGS; then
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN gogs --a-rec=$GOGS_IP
fi

if $ENABLE_CHAT; then
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN chat --a-rec=$CHAT_IP
fi

if $ENABLE_HIVE; then
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN cortex --a-rec=$CORTEX_IP
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN hive --a-rec=$HIVE_IP
fi

if $ENABLE_SPLUNK; then
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN splunk --a-rec=$SPLUNK_IP
fi

docker exec -iu root ipa ipa dnsrecord-del $DOMAIN ipa --a-rec 172.19.0.253
docker exec -iu root ipa ipa dnsrecord-del $DOMAIN ipa-ca --a-rec 172.19.0.253

################################################################################
# CONFIGURE: First User/Admin                                                  #
################################################################################
# Set default shell to /bin/bash (because)
docker exec -iu root ipa ipa config-mod --defaultshell=/bin/bash

# Set default password policy
docker exec -itu root ipa ipa pwpolicy-mod --minlife=0 --minlength=0 --minclasses=0 global_policy

# Create and configure default group
docker exec -iu root ipa ipa group-add users --desc="Default group"
docker exec -iu root ipa ipa config-mod --defaultgroup=users

# create new IPA user
yes $IPA_ADMIN_PASSWORD | docker exec -iu root ipa ipa user-add $IPA_USERNAME \
            --first=cozy --last=admin \
            --homedir=/home/$IPA_USERNAME \
            --shell=/bin/bash \
            --password

# add IPA user to admins
docker exec -iu root ipa ipa group-add-member admins --users=$IPA_USERNAME


if $ENABLE_HIVE; then
# Create first TheHive user (give it time to reboot)
curl -XPOST -H 'Content-Type: application/json' -k https://hive.$DOMAIN/api/user -d "{
  \"login\": \"localadmin\",
  \"name\": \"Cozy Admin\",
  \"roles\": [\"read\", \"write\", \"admin\"],
  \"password\": \"$IPA_ADMIN_PASSWORD\"
}"
fi
