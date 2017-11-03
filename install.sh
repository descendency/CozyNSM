################################################################################
# Configure Variables below to your hardware settings.                         #
################################################################################
# For setting up collection interface (ex: eth0)
#COLLECTION_INTERFACE=<>
echo "Interface List:"
ip addr | grep -e ^[0-9] | awk -F ' '  '{print $2}' | cut -d ':' -f1
echo ""
read -p "Collection Interface? " COLLECTION_INTERFACE
# For setting up the interface analysts talk to (ex: eth0)
#ANALYST_INTERFACE=<>
echo ""
echo "Interface List:"
ip addr | grep -e ^[0-9] | awk -F ' '  '{print $2}' | cut -d ':' -f1
echo ""
read -p "Analysis Interface? " ANALYST_INTERFACE
# The name of the domain (ex: example.com)
#DOMAIN=<>
read -p "Domain? " DOMAIN
# Default IPA Administrator Username
read -p "Admin Name (no spaces)? " IPA_USERNAME
# Default IPA Administrator password.
#IPA_ADMIN_PASSWORD=<>
read -p "Admin Password? " IPA_ADMIN_PASSWORD
################################################################################
# ADVANCED CONFIGURATION --- EDIT BELOW FOR ADVANCED USERS                     #
################################################################################
# Number of Bro workers to process traffic.
# 4 workers per 1 Gbps of traffic.
BRO_WORKERS=4      # For VMs
# Heap Space Allocation for Elasticsearch (do NOT use over 31g)
ES_RAM=2g     # 2GiB Heap Space for Elasticsearch (For VMs)
# How many ElasticSearch Data nodes do you want? (Remember: there is 1 Master
# and 1 Search Node, already.)
ES_DATA_NODES=2
# For disabling the stenographer install - because it takes up a lot of
# resources unnecessarily, for testing.
ENABLE_STENOGRAPHER=true
ENABLE_MOLOCH=false
ENABLE_ELK=true
ENABLE_SPLUNK=true
ENABLE_TOOLS=true
ENABLE_SURICATA=true
ENABLE_BRO=true
# Number of stenographer collection threads.
# 1 thread per 1 Gbps of traffic, minimum 2 threads.
STENO_THREADS=2
# Grab the IP from the analyst interface. This prevents users from incorrectly
# inputting the first 3 octets.
# Format Example: 192.168.1
IP=$(ip addr | grep -e 'inet ' | grep -e ".*$ANALYST_INTERFACE$" | awk \
    '{print $2}' | cut -f1 -d '/' | awk -F . '{print $1"."$2"."$3}')
# The IP schema of the server and its applications.
IPA_IP=$IP.5
ES_IP=$IP.6
ESSEARCH_IP=$IP.7
KIBANA_IP=$IP.8
OWNCLOUD_IP=$IP.9
GOGS_IP=$IP.10
CHAT_IP=$IP.11
SPLUNK_IP=$IP.12
ESDATA_IP=$IP.13

IPCOUNTER=0
################################################################################
# CONFIGURATION SCRIPT --- EDIT BELOW AT YOUR OWN RISK                         #
################################################################################
# Extracts all of the files to begin installation
#tar xzvf server.tar.gz

# Ensure FreeIPA is the default DNS server.
if grep -q DNS1 /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE; then
   sed -e "s@DNS1=\\"?.*\\"?@DNS1=\"$IPA_IP\"@g" -i /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE
else
    echo -e "\nDNS1=\"$IPA_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE
fi
systemctl restart network

# Locally installs required RPMs for every application.
yum -y localinstall rpm/updates/*.rpm
yum -y localinstall rpm/extras/*.rpm
yum -y localinstall rpm/docker/*.rpm
yum -y localinstall rpm/ipa-client/*.rpm
yum -y localinstall rpm/filebeat/*.rpm
yum -y localinstall rpm/bro/*.rpm
yum -y localinstall rpm/bro/*.rpm
yum -y localinstall rpm/suricata/*.rpm
yum -y localinstall rpm/stenographer/*.rpm

# Points the server to its proper DNS server (FreeIPA).
echo -e "\nnameserver $IPA_IP\n" >> /etc/resolv.conf

# Allow IPA admins to sudo.
echo -e "%admins ALL=(ALL)\tALL\n" >> /etc/sudoers

#------------------------------------------------------------------------------#
# Beginning: Sensor Configuration                                              #
#------------------------------------------------------------------------------#

# Creating directories ahead of install for scripted ELK configuration.
mkdir -p /data/bro/current
mkdir -p /data/bro/spool

# Create CozyStack installed event.
echo "{\"ts\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"source\":\"Install Script\", \"message\": \"CozyStack installed. This is needed for ELK to initialize correctly.\"}" > /data/bro/current/cozy.log

################################################################################
# INSTALL: Bro NSM                                                             #
################################################################################
if $ENABLE_BRO; then
    BRO_DIR=/opt
    # Configure Bro to run in clustered mode.
    cp bro/etc/node.cfg $BRO_DIR/bro/etc/node.cfg
    # Configure the number of nodes for Bro.
    COUNTER=2
    while [ $COUNTER -le $BRO_WORKERS ]; do
      echo [worker-$COUNTER] >> $BRO_DIR/bro/etc/node.cfg
      echo type=worker >> $BRO_DIR/bro/etc/node.cfg
      echo host=localhost >> $BRO_DIR/bro/etc/node.cfg
      echo interface=af_packet::$COLLECTION_INTERFACE >> $BRO_DIR/bro/etc/node.cfg
      let COUNTER=COUNTER+1
    done
    # Configure the interface to listen on.
    sed -e "s/INTERFACE/$COLLECTION_INTERFACE/g" -i $BRO_DIR/bro/etc/node.cfg
    # Configure the BroCTL to have a temporary in-place sensor setup.
    cp bro/etc/broctl.cfg $BRO_DIR/bro/etc/broctl.cfg
    # Disable certain logs and output in JSON.
    cp bro/etc/local.bro $BRO_DIR/bro/share/bro/site/local.bro
################################################################################
# DEPLOY: Bro NSM                                                              #
################################################################################
    ln -s $BRO_DIR/bro/bin/bro /usr/bin/bro
    ln -s $BRO_DIR/bro/bin/broctl /usr/bin/broctl
    $BRO_DIR/bro/bin/broctl install
    $BRO_DIR/bro/bin/broctl deploy
    $BRO_DIR/bro/bin/broctl stop
    cp bro/etc/bro.service /etc/systemd/system
    systemctl enable bro
    systemctl start bro
fi
################################################################################
# INSTALL: Suricata IDS                                                        #
################################################################################
if $ENABLE_SURICATA; then
    cp suricata/etc/suricata.yaml /etc/suricata/suricata.yaml
    sed -e "s/DEVICENAME/$COLLECTION_INTERFACE/g" -i /etc/suricata/suricata.yaml
    ethtool -K $COLLECTION_INTERFACE lro off
    ethtool -K $COLLECTION_INTERFACE gro off
    ldconfig /usr/local/lib
    cp suricata/suricata.service /etc/systemd/system
    sed -e "s/INTERFACE/$COLLECTION_INTERFACE/g" \
        -i /etc/systemd/system/suricata.service
    systemctl enable suricata
    systemctl start suricata
################################################################################
# CONFIGURE: Suricata Rules                                                    #
################################################################################
    mkdir /etc/suricata/rules
    cp suricata/rules/emerging-all.rules /etc/suricata/rules
fi

################################################################################
# INSTALL: Google Stenographer                                                 #
################################################################################
if $ENABLE_STENOGRAPHER; then
    let STENO_THREADS=STENO_THREADS-1
    COUNTER=0
    while [ $COUNTER -le $STENO_THREADS ]; do
        mkdir -p /data/index/$COUNTER
        chown stenographer:stenographer /data/index/$COUNTER
        mkdir -p /data/packets/$COUNTER
        chown stenographer:stenographer /data/packets/$COUNTER

        PDIR="\"PacketsDirectory\"\: \"\/data\/packets\/$COUNTER\""
        IDIR="\"IndexDirectory\"\: \"\/data\/index\/$COUNTER\""
        LINE="\n\t$PDIR\,\n\t$IDIR\n\t"

        if [ $COUNTER -eq $STENO_THREADS ]; then
            sed -e "s/THREADHOLDER/\t\{$LINE\}/g" \
                -i stenographer/config
        else
            sed -e "s/THREADHOLDER/\t\{$LINE\}\,\nTHREADHOLDER/g" \
                -i stenographer/config
        fi
        let COUNTER=COUNTER+1
    done

    cp stenographer/config /etc/stenographer/config
    sed -e "s/placeholder/$COLLECTION_INTERFACE/g" -i /etc/stenographer/config
    chmod 755 /etc/stenographer
    chown stenographer:stenographer /etc/stenographer/certs
    chmod 750 /etc/stenographer/certs
    systemctl enable stenographer
    systemctl start stenographer
fi
################################################################################
# INSTALL: FileBeat                                                            #
################################################################################
if $ENABLE_ELK; then
    cp filebeat/filebeat.yml /etc/filebeat/filebeat.yml
    systemctl enable filebeat
    systemctl start filebeat
fi

#------------------------------------------------------------------------------#
# END: Sensor Configuration                                                    #
#------------------------------------------------------------------------------#

#------------------------------------------------------------------------------#
# Beginning: Application Configuration                                         #
#------------------------------------------------------------------------------#

# Automates the sysctl commands below, on boot
echo "net.ipv4.conf.all.forwarding=1" >> /usr/lib/sysctl.d/00-system.conf
echo "vm.max_map_count=1073741824" >> /usr/lib/sysctl.d/00-system.conf

# Improve Query time in Splunk and ElasticSearch.
cp initd/disable-transparent-hugepages /etc/init.d/disable-transparent-hugepages
chmod 755 /etc/init.d/disable-transparent-hugepages
chkconfig --add disable-transparent-hugepages

# Routes packets internally for docker
sysctl -w net.ipv4.conf.all.forwarding=1

# Fixes an ElasticSearch issue in 5.x+
sysctl -w vm.max_map_count=1073741824

# Generate SSL certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout nginx/nginx.key -out nginx/nginx.crt -subj "/C=US/ST=/L=/O=CozyStack/OU=CozyStack/CN=$DOMAIN"
openssl req -out nginx/nginx.csr -key nginx/nginx.key -new -subj "/C=US/ST=/L=/O=CozyStack/OU=CozyStack/CN=$DOMAIN"
cat nginx/nginx.crt nginx/nginx.key > nginx/nginx.pem

################################################################################
# INSTALL: Docker                                                              #
################################################################################
systemctl enable docker
systemctl start docker
systemctl enable rngd
systemctl start rngd

docker network create --driver=bridge --subnet=172.18.0.0/24 br0
################################################################################
# LOAD: Docker Images                                                          #
################################################################################
docker load -i ./images/freeipa.docker

if $ENABLE_ELK; then
    docker load -i ./images/logstash.docker
    docker load -i ./images/elasticsearch.docker
    docker load -i ./images/kibana.docker
fi

if $ENABLE_TOOLS; then
    docker load -i ./images/gogs.docker
    docker load -i ./images/owncloud.docker
    docker load -i ./images/mongo.docker
    docker load -i ./images/rocketchat.docker
fi

if $ENABLE_SPLUNK; then
    docker load -i ./images/splunk.docker
    docker load -i ./images/busybox.docker
    docker load -i ./images/universalforwarder.docker
fi

docker load -i ./images/nginx.docker
################################################################################
# INSTALL: FreeIPA                                                             #
################################################################################
bash interface.sh $ANALYST_INTERFACE $IPA_IP $IPCOUNTER
let IPCOUNTER=IPCOUNTER+1
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

docker run --name ipa --restart=always -ti -h ipa.$DOMAIN --privileged \
            -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
            --network="br0" \
            --ip 172.18.0.253 \
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

# Fixes a memory assignemnt issue I still don't completely understand.
sysctl vm.drop_caches=3
################################################################################
# INSTALL: Logstash                                                            #
################################################################################
if $ENABLE_ELK; then
    bash interface.sh $ANALYST_INTERFACE $ES_IP $IPCOUNTER
    let IPCOUNTER=IPCOUNTER+1
    docker run --restart=always -itd --name logstash -h logstash.$DOMAIN \
                -p $ES_IP:5044:5044 \
                -p $ES_IP:9600:9600 \
                --network="br0" \
                --ip 172.18.0.3 \
                logstash

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3

    pushd ./logstash
    tar xzvf GeoLite2-City.tar.gz --strip-components=1
    popd
    docker exec -iu logstash logstash mkdir /usr/share/logstash/GeoIP
    docker cp logstash/GeoLite2-City.mmdb \
        logstash:/usr/share/logstash/GeoIP/GeoLite2-City.mmdb
    docker exec -iu root logstash chown logstash:logstash \
        /usr/share/logstash/GeoIP/GeoLite2-City.mmdb
    docker cp logstash/logstash.conf \
        logstash:/usr/share/logstash/pipeline/logstash.conf
    docker cp logstash/logstash.yml \
        logstash:/usr/share/logstash/config/logstash.yml
################################################################################
# INSTALL: ElasticSearch Master Node                                           #
################################################################################
    docker run --restart=always -itd --name es -h es.$DOMAIN \
                -p $ES_IP:9200:9200 \
                -p $ES_IP:9300:9300 \
                --network="br0" \
                --ip 172.18.0.$(echo $ES_IP | awk -F . '{print $4}') \
                -e ES_JAVA_OPTS="-Xms$ES_RAM -Xmx$ES_RAM" \
                elasticsearch

    COUNTER=0
    while [ $COUNTER -lt $ES_DATA_NODES ]; do
        sed -e "s/CENSOR/  - name: \"CozyData$COUNTER\"\nCENSOR/g" -i elasticsearch/instances.yml
        let COUNTER=COUNTER+1
    done
    sed -e "s/CENSOR//g" -i elasticsearch/instances.yml
    docker cp elasticsearch/instances.yml es:/usr/share/elasticsearch/config/x-pack/instances.yml
    echo certs.zip | docker exec -iu root es /usr/share/elasticsearch/bin/x-pack/certgen --in instances.yml
    mkdir certs
    docker cp es:/usr/share/elasticsearch/config/x-pack/certs.zip certs/certs.zip
    unzip certs/certs.zip -d certs
    openssl x509 -inform PEM -in certs/ca/ca.crt > certs/ca/ca.pem
    openssl pkcs8 -in certs/Logstash/Logstash.key -topk8 -nocrypt -out certs/Logstash/Logstash.p8

    docker cp certs/ca/ca.pem \
        logstash:/usr/share/logstash/config/ca.pem
    docker cp certs/Logstash/Logstash.crt \
        logstash:/usr/share/logstash/config/Logstash.crt
    docker cp certs/Logstash/Logstash.p8 \
        logstash:/usr/share/logstash/config/Logstash.key
    docker restart logstash

    cp certs/FileBeat/FileBeat.crt /etc/filebeat/FileBeat.crt
    cp certs/ca/ca.crt /etc/filebeat/ca.crt
    cp certs/FileBeat/FileBeat.key /etc/filebeat/FileBeat.key
    systemctl restart filebeat

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3

    sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" \
                -e "s/IPAPASS/$IPA_ADMIN_PASSWORD/g" \
                -e "s/IPA_IP/$IPA_IP/g" \
                -e "s/ES_IP/$ES_IP/g" \
                -i elasticsearch/elasticsearch.yml
    docker cp elasticsearch/elasticsearch.yml \
        es:/usr/share/elasticsearch/config/elasticsearch.yml
    sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" -i elasticsearch/role_mapping.yml
    docker cp elasticsearch/role_mapping.yml \
        es:/usr/share/elasticsearch/config/x-pack/role_mapping.yml
    docker cp certs/CozyMaster/CozyMaster.key \
        es:/usr/share/elasticsearch/config/x-pack/CozyMaster.key
    docker cp certs/CozyMaster/CozyMaster.crt \
        es:/usr/share/elasticsearch/config/x-pack/CozyMaster.crt
    docker cp certs/ca/ca.crt \
        es:/usr/share/elasticsearch/config/x-pack/ca.crt
################################################################################
# INSTALL: ElasticSearch Search Node                                           #
################################################################################
    bash interface.sh $ANALYST_INTERFACE $ESSEARCH_IP $IPCOUNTER
    let IPCOUNTER=IPCOUNTER+1
    docker run --restart=always -itd --name essearch -h essearch.$DOMAIN \
                -p $ESSEARCH_IP:9200:9200 \
                -p $ESSEARCH_IP:9300:9300 \
                --network="br0" \
                --ip 172.18.0.$(echo $ESSEARCH_IP | awk -F . '{print $4}') \
                -e ES_JAVA_OPTS="-Xms$ES_RAM -Xmx$ES_RAM" \
                elasticsearch

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3

    sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" \
                -e "s/IPAPASS/$IPA_ADMIN_PASSWORD/g" \
                -e "s/LOCALDOMAIN/$DOMAIN/g" \
                -e "s/IPA_IP/$IPA_IP/g" \
                -e "s/ES_IP/$ESSEARCH_IP/g" \
                -i elasticsearch/elasticsearch_search.yml
    docker cp elasticsearch/elasticsearch_search.yml \
        essearch:/usr/share/elasticsearch/config/elasticsearch.yml
    sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" -i elasticsearch/role_mapping.yml
    docker cp elasticsearch/role_mapping.yml \
        essearch:/usr/share/elasticsearch/config/x-pack/role_mapping.yml
    docker cp certs/CozySearch/CozySearch.key \
        essearch:/usr/share/elasticsearch/config/x-pack/CozySearch.key
    docker cp certs/CozySearch/CozySearch.crt \
        essearch:/usr/share/elasticsearch/config/x-pack/CozySearch.crt
    docker cp certs/ca/ca.crt \
        essearch:/usr/share/elasticsearch/config/x-pack/ca.crt

    docker restart es essearch
################################################################################
# INSTALL: ElasticSearch Data Node(s)                                          #
################################################################################
    COUNTER=0
    while [ $COUNTER -lt $ES_DATA_NODES ]; do
        TMP_IP=$(echo $ESDATA_IP | cut -d. -f1-3).$(($(echo $ESDATA_IP | cut \
            -d. -f4)+$COUNTER))
        bash interface.sh $ANALYST_INTERFACE $TMP_IP $(($IPCOUNTER+$COUNTER))
        let IPCOUNTER=IPCOUNTER+1
        docker run --restart=always -itd --name esdata$COUNTER \
                    -h esdata$COUNTER.$DOMAIN \
                    -p $TMP_IP:9200:9200 \
                    -p $TMP_IP:9300:9300 \
                    --network="br0" \
                    --ip 172.18.0.$(echo $TMP_IP | awk -F . '{print $4}') \
                    -e ES_JAVA_OPTS="-Xms$ES_RAM -Xmx$ES_RAM" \
                    elasticsearch

        # Fixes a memory assignemnt issue I still don't completely understand.
        sysctl vm.drop_caches=3

        cp elasticsearch/elasticsearch_data.yml tmp.yml
        sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" \
                    -e "s/NUMBER/$COUNTER/g" \
                    -e "s/IPAPASS/$IPA_ADMIN_PASSWORD/g" \
                	-e "s/LOCALDOMAIN/$DOMAIN/g" \
                    -e "s/IPA_IP/$IPA_IP/g" \
                    -e "s/ES_IP/$TMP_IP/g" \
                    -i tmp.yml
        docker cp tmp.yml \
            esdata$COUNTER:/usr/share/elasticsearch/config/elasticsearch.yml
        rm -f tmp.yml
        sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" \
            -i elasticsearch/role_mapping.yml
        docker cp elasticsearch/role_mapping.yml \
            esdata$COUNTER:/usr/share/elasticsearch/config/x-pack/role_mapping.yml

        docker cp certs/CozyData$COUNTER/CozyData$COUNTER.key \
            esdata$COUNTER:/usr/share/elasticsearch/config/x-pack/CozyData$COUNTER.key
        docker cp certs/CozyData$COUNTER/CozyData$COUNTER.crt \
            esdata$COUNTER:/usr/share/elasticsearch/config/x-pack/CozyData$COUNTER.crt
        docker cp certs/ca/ca.crt \
            esdata$COUNTER:/usr/share/elasticsearch/config/x-pack/ca.crt
        docker restart esdata$COUNTER
      let COUNTER=COUNTER+1
    done
################################################################################
# INSTALL: Kibana                                                              #
################################################################################
    bash interface.sh $ANALYST_INTERFACE $KIBANA_IP $IPCOUNTER
    let IPCOUNTER=IPCOUNTER+1
    docker run --restart=always -itd --name kibana -h kibana.$DOMAIN \
                --network="br0" \
                --ip 172.18.0.$(echo $KIBANA_IP | awk -F . '{print $4}') \
                kibana

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3

    docker cp kibana/kibana.yml kibana:/usr/share/kibana/config/kibana.yml
    docker cp certs/ca/ca.pem kibana:/usr/share/kibana/config/ca.pem
    docker cp certs/kibana/kibana.key \
        kibana:/usr/share/kibana/config/kibana.key
    docker cp certs/kibana/kibana.crt \
        kibana:/usr/share/kibana/config/kibana.crt

    docker restart kibana
fi
################################################################################
# INSTALL: GoGS                                                                #
################################################################################
if $ENABLE_TOOLS; then
    bash interface.sh $ANALYST_INTERFACE $GOGS_IP $IPCOUNTER
    let IPCOUNTER=IPCOUNTER+1
    docker run --restart=always -itd --name gogs -h gogs.$DOMAIN \
                --ip 172.18.0.$(echo $GOGS_IP | awk -F . '{print $4}') \
                --network="br0" \
                -p $GOGS_IP:1022:22 \
                -p $GOGS_IP:443:3000 \
                gogs

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3
    docker exec -itu root gogs mkdir /app/certs
    docker cp nginx/nginx.key gogs:/app/certs/nginx.key
    docker cp nginx/nginx.crt gogs:/app/certs/nginx.crt
    docker restart gogs
################################################################################
# INSTALL: MongoDB for Rocket.Chat                                             #
################################################################################
    bash interface.sh $ANALYST_INTERFACE $CHAT_IP $IPCOUNTER
    let IPCOUNTER=IPCOUNTER+1
    docker run --name mongodb --restart=always -tid -h mongodb.$DOMAIN \
                -p $CHAT_IP:27017:27017 \
                --ip 172.18.0.4 \
                --network="br0" \
                mongo

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3
################################################################################
# INSTALL: Rocket.Chat                                                         #
################################################################################
    docker run --name chat --restart=always -tid -h chat.$DOMAIN \
                --ip 172.18.0.$(echo $CHAT_IP | awk -F . '{print $4}') \
                --network="br0" \
    			-e OVERWRITE_SETTING_LDAP_Enable="True" \
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
    			-e MONGO_URL=mongodb://$CHAT_IP/mydb \
    			-e ADMIN_USERNAME=cozyadmin \
    			-e ADMIN_PASS=$IPA_ADMIN_PASSWORD \
    			-e ADMIN_EMAIL=cozyadmin@cozy.lan \
    			--link mongodb \
                rocketchat

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3
################################################################################
# INSTALL: OwnCloud                                                            #
################################################################################
    bash interface.sh $ANALYST_INTERFACE $OWNCLOUD_IP $IPCOUNTER
    let IPCOUNTER=IPCOUNTER+1
    docker run --restart=always -itd --name owncloud -h owncloud.$DOMAIN \
                --ip 172.18.0.$(echo $OWNCLOUD_IP | awk -F . '{print $4}') \
                --network="br0" \
                -p $OWNCLOUD_IP:80:80 \
                -p $OWNCLOUD_IP:443:443 \
                owncloud

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3

fi
################################################################################
# INSTALL: BusyBox for Splunk Enterprise                                       #
################################################################################
if $ENABLE_SPLUNK; then
    bash interface.sh $ANALYST_INTERFACE $SPLUNK_IP $IPCOUNTER
    let IPCOUNTER=IPCOUNTER+1
    docker run --restart=always -itd --name vsplunk -h busybox.$DOMAIN \
                --network="br0" \
                -v /opt/splunk/etc \
                -v /opt/splunk/var \
                busybox

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3
################################################################################
# INSTALL: Splunk Enterprise                                                   #
################################################################################
    docker run --restart=always -itd --name splunk -h splunk.$DOMAIN \
                --volumes-from=vsplunk \
                -v /data/bro/current:/data/bro/current:ro \
                --ip 172.18.0.$(echo $SPLUNK_IP | awk -F . '{print $4}') \
                --network="br0" \
                -p $SPLUNK_IP:9997:9997 \
                -p $SPLUNK_IP:8088:8088 \
                -p $SPLUNK_IP:1514:1514 \
                -e "SPLUNK_START_ARGS=--accept-license" \
                splunk

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3

fi

################################################################################
# Auto Configure SSO                                                           #
################################################################################

#gogs
sed -e "s/GOGSDOMAIN/gogs.$DOMAIN/g" -i gogs/app.ini
docker cp gogs/app.ini gogs:/data/gogs/conf/app.ini
sqlite3 gogs/gogs.db "$(sed -e "s/IPA_IP/$IPA_IP/g" -e "s/DOMAIN/dc=${DOMAIN//\./,dc=}/g" -e "s/ADMIN_PASSWORD/$IPA_ADMIN_PASSWORD/g" gogs/test.txt)"
docker cp gogs/gogs.db gogs:/app/gogs/data/gogs.db
docker exec -itu root gogs chmod a+w /app/gogs/data/gogs.db
docker exec -itu root gogs chmod a+w /data/gogs/data
docker restart gogs

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
docker exec -itu www-data owncloud php occ maintenance:install --database="sqlite" --database-name="owncloud" --database-table-prefix="oc_" --admin-user "cozyadmin" --admin-pass "$IPA_ADMIN_PASSWORD"
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

################################################################################
# INSTALL: Splunk Forwarders                                                   #
################################################################################
#
################################################################################
# INSTALL: TheHive With Cortex                                                 #
################################################################################
#
################################################################################
# INSTALL: DokuWiki                                                            #
################################################################################
#
################################################################################
# INSTALL: NGINX Reverse Proxy                                                 #
################################################################################
# Create the reverse proxy
docker run --restart=always -itd --name proxy -h proxy.$DOMAIN \
            --ip 172.18.0.51 \
            --network="br0" \
            -p $SPLUNK_IP:80:80 \
            -p $CHAT_IP:80:80 \
            -p $KIBANA_IP:80:80 \
            -p $SPLUNK_IP:443:443 \
            -p $CHAT_IP:443:443 \
            -p $KIBANA_IP:443:443 \
            -p $GOGS_IP:80:80 \
            nginx

# Copy SSL Certs into directories
docker exec -itu root proxy mkdir /etc/nginx/ssl
docker cp nginx/nginx.key proxy:/etc/nginx/ssl/nginx.key
docker cp nginx/nginx.crt proxy:/etc/nginx/ssl/nginx.crt
### Modify the configuration
sed -e "s/DOMAIN/$DOMAIN/g" \
    -e "s/GOGSIP/172.18.0.$(echo $GOGS_IP | awk -F . '{print $4}')/g" \
    -e "s/OWNCLOUDIP/172.18.0.$(echo $OWNCLOUD_IP | awk -F . '{print $4}')/g" \
    -e "s/CHATIP/172.18.0.$(echo $CHAT_IP | awk -F . '{print $4}')/g" \
    -e "s/KIBANAIP/172.18.0.$(echo $KIBANA_IP | awk -F . '{print $4}')/g" \
    -e "s/GOGSIP/172.18.0.$(echo $GOGS_IP | awk -F . '{print $4}')/g" \
    -e "s/SPLUNKIP/172.18.0.$(echo $SPLUNK_IP | awk -F . '{print $4}')/g" \
    -i nginx/nginx.conf
docker cp nginx/nginx.conf proxy:/etc/nginx/nginx.conf

# Start Reverse Proxy
docker restart proxy

################################################################################
# INSTALL: File Scanning Framework                                             #
################################################################################
#

################################################################################
# CONFIGURE: DNS                                                               #
################################################################################
# Sign in as IPA admin
echo $IPA_ADMIN_PASSWORD | docker exec -iu root ipa kinit admin

# Create DNS A-Records
docker exec -iu root ipa ipa dnsrecord-add $DOMAIN ipa --a-rec=$IPA_IP
docker exec -iu root ipa ipa dnsrecord-add $DOMAIN ipa-ca --a-rec=$IPA_IP

if $ENABLE_ELK; then
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN elasticsearch --a-rec=$ES_IP
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN es --a-rec=$ES_IP
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN essearch --a-rec=$ESSEARCH_IP
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN logstash --a-rec=$ES_IP
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN kibana --a-rec=$KIBANA_IP
fi

if $ENABLE_TOOLS; then
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN owncloud --a-rec=$OWNCLOUD_IP
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN cloud --a-rec=$OWNCLOUD_IP
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN gogs --a-rec=$GOGS_IP
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN chat --a-rec=$CHAT_IP
fi

if $ENABLE_SPLUNK; then
    docker exec -iu root ipa ipa dnsrecord-add $DOMAIN splunk --a-rec=$SPLUNK_IP
fi

docker exec -iu root ipa ipa dnsrecord-del $DOMAIN ipa --a-rec 172.18.0.2
docker exec -iu root ipa ipa dnsrecord-del $DOMAIN ipa-ca --a-rec 172.18.0.2

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

# Create new admin's home directory
cp -R /etc/skel /home
mv /home/skel /home/$IPA_USERNAME

# Automate the Kibana Index Choosing
curl -k -u $IPA_USERNAME:$IPA_ADMIN_PASSWORD -XPUT https://es.$DOMAIN:9200/.kibana/index-pattern/logstash-* -d '{"title" : "logstash-*",  "timeFieldName": "ts"}'
curl -k -u $IPA_USERNAME:$IPA_ADMIN_PASSWORD -XPUT https://es.$DOMAIN:9200/.kibana/config/4.1.1 -d '{"defaultIndex" : "logstash-*"}'

# Configure IPA client
ipa-client-install -U --server=ipa.$DOMAIN \
                    --domain=$DOMAIN \
                    -p admin \
                    -w $IPA_ADMIN_PASSWORD \
                    --mkhomedir \
                    --hostname server.$DOMAIN \
                    --ntp-server=ipa.$DOMAIN

# Remove root access
sed -e 's/^#PermitRootLogin yes$/PermitRootLogin no/g' -i /etc/ssh/sshd_config
sed -e 's@^\(root.*\)/bin/bash$@\1/sbin/nologin@g' -i /etc/passwd
