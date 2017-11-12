################################################################################
# Configure Variables below to your hardware settings.                         #
################################################################################
# Ensure the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# For setting up collection interface (ex: eth0)
#COLLECTION_INTERFACE=<>
#echo "Interface List:"
#ip addr | grep -e ^[0-9] | awk -F ' '  '{print $2}' | cut -d ':' -f1
#echo ""
#read -p "Collection Interface? " COLLECTION_INTERFACE
# For setting up the interface analysts talk to (ex: eth0)
#ANALYST_INTERFACE=<>
echo ""
echo "Interface List:"
ip addr | grep -e ^[0-9] | awk -F ' '  '{print $2}' | cut -d ':' -f1
echo ""
read -p "Analysis Interface? " ANALYST_INTERFACE
# The name of the domain (ex: example.com)
#DOMAIN=<>
#read -p "Domain? " DOMAIN
# Check to see if the server is correctly named and skip the DOMAIN assignment
# if it is. Otherwise, prompt the user for a domain name.
if (($(hostname | grep -o "\." | wc -l) > 1)); then DOMAIN=$(echo `hostname` | sed 's/^[^\.]*\.//g'); else read -p "Domain? " DOMAIN; fi
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
#BRO_WORKERS=4      # For VMs
# Heap Space Allocation for Elasticsearch (do NOT use over 31g)
ES_RAM=2g     # 2GiB Heap Space for Elasticsearch (For VMs)
# How many ElasticSearch Data nodes do you want? (Remember: there is 1 Master
# and 1 Search Node, already.)
ES_DATA_NODES=2
# For disabling the stenographer install - because it takes up a lot of
# resources unnecessarily, for testing.
ENABLE_STENOGRAPHER=true
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
HIVE_IP=$IP.13
CORTEX_IP=$IP.14
ESDATA_IP=$IP.15

IPCOUNTER=0
################################################################################
# CONFIGURATION SCRIPT --- EDIT BELOW AT YOUR OWN RISK                         #
################################################################################
# Firewalld is currently broken with docker. Until the issue is fixed, it must
# be turned off.
systemctl disable firewalld
systemctl stop firewalld

# Disable the local GPG requirement
# Enabled at the end of the script. (DISA STIG)
sed -e "s/repo_gpgcheck=1/repo_gpgcheck=0/g" -e "s/localpkg_gpgcheck=1/localpkg_gpgcheck=0/g" -i /etc/yum.conf
yum clean all

# Ensure FreeIPA is the default DNS server.
if grep -q DNS1 /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE; then
   sed -e "s@DNS1=\\"?.*\\"?@DNS1=\"$IPA_IP\"@g" -i /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE
else
    echo -e "\nDNS1=\"$IPA_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE
fi
systemctl restart network

# Locally installs required RPMs for every application.
mkdir /tmp/backup
mv /etc/yum.repos.d/* /tmp/backup
yum -y localinstall rpm/updates/*.rpm
yum -y localinstall rpm/extras/*.rpm
yum -y localinstall rpm/docker/*.rpm
yum -y localinstall rpm/ipa-client/*.rpm
yum -y localinstall rpm/filebeat/*.rpm
yum -y localinstall rpm/bro/*.rpm
yum -y localinstall rpm/suricata/*.rpm
yum -y localinstall rpm/stenographer/*.rpm
mv /tmp/backup/* /etc/yum.repos.d
# Points the server to its proper DNS server (FreeIPA).
echo -e "\nnameserver $IPA_IP\n" >> /etc/resolv.conf

# Allow IPA admins to sudo.
echo -e "%admins ALL=(ALL)\tALL\n" >> /etc/sudoers

# Automates the sysctl commands below, on boot
echo "net.ipv4.conf.all.forwarding=1" >> /usr/lib/sysctl.d/00-system.conf
#echo "net.ipv6.conf.all.disable_ipv6=1" >> /usr/lib/sysctl.d/00-system.conf
echo "vm.max_map_count=1073741824" >> /usr/lib/sysctl.d/00-system.conf

# Improve Query time in Splunk and ElasticSearch.
cp initd/disable-transparent-hugepages /etc/init.d/disable-transparent-hugepages
chmod 755 /etc/init.d/disable-transparent-hugepages
chkconfig --add disable-transparent-hugepages

# Routes packets internally for docker
sysctl -w net.ipv4.conf.all.forwarding=1

sysctl -w net.ipv6.conf.all.enable_ipv6=1
#sysctl -w net.ipv6.conf.lo.enable_ipv6=1

# Fixes an ElasticSearch issue in 5.x+
sysctl -w vm.max_map_count=1073741824
systemctl restart network

# Generate SSL certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout nginx/nginx.key -out nginx/nginx.crt -subj "/C=US/ST=/L=/O=CozyStack/OU=CozyStack/CN=$DOMAIN"
openssl req -out nginx/nginx.csr -key nginx/nginx.key -new -subj "/C=US/ST=/L=/O=CozyStack/OU=CozyStack/CN=$DOMAIN"
cat nginx/nginx.crt nginx/nginx.key > nginx/nginx.pem

################################################################################
# INSTALL: Docker                                                              #
################################################################################
systemctl enable docker
systemctl start docker

docker network create --driver=bridge --subnet=172.18.0.0/24 --gateway=172.18.0.1 --ipv6 --subnet=2001:3200:3200::/64 --gateway=2001:3200:3200::1 databridge
################################################################################
# LOAD: Docker Images                                                          #
################################################################################
if $ENABLE_ELK; then
    docker load -i ./images/logstash.docker
    docker load -i ./images/elasticsearch.docker
    docker load -i ./images/kibana.docker
fi

if $ENABLE_SPLUNK; then
    docker load -i ./images/splunk.docker
    docker load -i ./images/busybox.docker
    docker load -i ./images/universalforwarder.docker
fi

docker load -i ./images/nginx.docker

################################################################################
# INSTALL: Logstash                                                            #
################################################################################
if $ENABLE_ELK; then
    bash interface.sh $ANALYST_INTERFACE $ES_IP $IPCOUNTER
    let IPCOUNTER=IPCOUNTER+1
    docker run --restart=always -itd --name logstash -h logstash.$DOMAIN \
                -p $ES_IP:5044:5044 \
                --network="databridge" \
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
                --network="databridge" \
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
    openssl x509 -inform PEM -in certs/ca/ca.crt > certs/ca/ca.pem
    openssl pkcs8 -in certs/Logstash/Logstash.key -topk8 -nocrypt -out certs/Logstash/Logstash.p8

    docker cp certs/ca/ca.pem \
        logstash:/usr/share/logstash/config/ca.pem
    docker cp certs/Logstash/Logstash.crt \
        logstash:/usr/share/logstash/config/Logstash.crt
    docker cp certs/Logstash/Logstash.p8 \
        logstash:/usr/share/logstash/config/Logstash.key
    docker restart logstash

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
                --network="databridge" \
                --ip 172.18.0.$(echo $ESSEARCH_IP | awk -F . '{print $4}') \
                -e ES_JAVA_OPTS="-Xms$ES_RAM -Xmx$ES_RAM" \
                elasticsearch

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3

    sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" \
                -e "s/IPAPASS/$IPA_ADMIN_PASSWORD/g" \
                -e "s/LOCALDOMAIN/$DOMAIN/g" \
                -e "s/IPA_IP/$IPA_IP/g" \
                -e "s/ES_IP/172.18.0.$(echo $ESSEARCH_IP | awk -F . '{print $4}')/g" \
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
                    --network="databridge" \
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
                    -e "s/ES_IP/172.18.0.$(echo $TMP_IP | awk -F . '{print $4}')/g" \
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
                --network="databridge" \
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
# INSTALL: BusyBox for Splunk Enterprise                                       #
################################################################################
if $ENABLE_SPLUNK; then
    bash interface.sh $ANALYST_INTERFACE $SPLUNK_IP $IPCOUNTER
    let IPCOUNTER=IPCOUNTER+1
    docker run --restart=always -itd --name vsplunk -h busybox.$DOMAIN \
                --network="databridge" \
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
                --network="databridge" \
                -p $SPLUNK_IP:9997:9997 \
                -p $SPLUNK_IP:8088:8088 \
                -p $SPLUNK_IP:1514:1514 \
                -e "SPLUNK_START_ARGS=--accept-license" \
                splunk

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3

fi

################################################################################
# INSTALL: NGINX Reverse Proxy                                                 #
################################################################################
# Create the reverse proxy
docker run --restart=always -itd --name dataproxy -h dataproxy.$DOMAIN \
            --ip 172.18.0.51 \
            --network="databridge" \
            -p $SPLUNK_IP:80:80 \
            -p $KIBANA_IP:80:80 \
            -p $SPLUNK_IP:443:443 \
            -p $KIBANA_IP:443:443 \
            nginx

# Copy SSL Certs into directories
docker exec -itu root dataproxy mkdir /etc/nginx/ssl
docker cp nginx/nginx.key dataproxy:/etc/nginx/ssl/nginx.key
docker cp nginx/nginx.crt dataproxy:/etc/nginx/ssl/nginx.crt

### Modify the configuration
sed -e "s/DOMAIN/$DOMAIN/g" \
    -e "s/GOGSIP/172.18.0.$(echo $GOGS_IP | awk -F . '{print $4}')/g" \
    -e "s/OWNCLOUDIP/172.18.0.$(echo $OWNCLOUD_IP | awk -F . '{print $4}')/g" \
    -e "s/CHATIP/172.18.0.$(echo $CHAT_IP | awk -F . '{print $4}')/g" \
    -e "s/KIBANAIP/172.18.0.$(echo $KIBANA_IP | awk -F . '{print $4}')/g" \
    -e "s/GOGSIP/172.18.0.$(echo $GOGS_IP | awk -F . '{print $4}')/g" \
    -e "s/SPLUNKIP/172.18.0.$(echo $SPLUNK_IP | awk -F . '{print $4}')/g" \
    -e "s/HIVEIP/172.19.0.10/g" \
    -e "s/CORTEXIP/172.19.0.12/g" \
    -i nginx/nginx.conf
docker cp nginx/nginx.conf dataproxy:/etc/nginx/nginx.conf

# Start Reverse proxy
docker restart dataproxy

################################################################################
# CONFIGURE: First User/Admin                                                  #
################################################################################
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

# Configure Firewall
#firewall-cmd --zone=public --add-port={22/tcp,80/tcp,53/udp,53/tcp,443/tcp,389/tcp,636/tcp,88/tcp,464/tcp,88/udp,464/udp,123/udp,7389/tcp,9443/tcp,9444/tcp,9445/tcp,5044/tcp,9600/tcp,9200/tcp,9300/tcp,1022/tcp,27017/tcp,9997/tcp,8088/tcp,1514/tcp} --permanent
#firewall-cmd --permanent --zone=trusted --change-interface=docker0
#firewall-cmd --zone=public --permanent --add-masquerade
#firewall-cmd --reload

sed -e "s/repo_gpgcheck=0/repo_gpgcheck=1/g" -e "s/localpkg_gpgcheck=0/localpkg_gpgcheck=1/g" -i /etc/yum.conf
yum clean all
