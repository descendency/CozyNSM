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

# Fixes a FreeIPA issue.
sysctl -w net.ipv6.conf.all.enable_ipv6=1

# Fixes an ElasticSearch issue in 5.x+
sysctl -w vm.max_map_count=1073741824
systemctl restart network

# Generate SSL certs
if [ ! -f nginx/nginx.key ]; then
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout nginx/nginx.key -out nginx/nginx.crt -subj "/C=US/ST=/L=/O=CozyStack/OU=CozyStack/CN=$DOMAIN"
openssl req -out nginx/nginx.csr -key nginx/nginx.key -new -subj "/C=US/ST=/L=/O=CozyStack/OU=CozyStack/CN=$DOMAIN"
fi

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
    docker load -q -i ./images/logstash.docker
    docker load -q -i ./images/elasticsearch.docker
    docker load -q -i ./images/kibana.docker
fi

if $ENABLE_SPLUNK; then
    docker load -q -i ./images/splunk.docker
    docker load -q -i ./images/busybox.docker
    docker load -q -i ./images/universalforwarder.docker
fi

docker load -q -i ./images/nginx.docker

################################################################################
# INSTALL: Logstash                                                            #
################################################################################
if $ENABLE_ELK; then
    if $IS_ELK_MASTER_NOTE; then
    bash scripts/interface.sh $ANALYST_INTERFACE $ES_IP $(($(ls /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE:* | wc -l) + 1))
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
    sed -i -e "s/SSLKEYPASS/$IPA_ADMIN_PASSWORD/g" logstash/logstash.conf
    docker cp logstash/logstash.conf \
        logstash:/usr/share/logstash/pipeline/logstash.conf
    docker cp logstash/logstash.yml \
        logstash:/usr/share/logstash/config/logstash.yml

    openssl x509 -inform PEM -in certs/ca/ca.crt > certs/ca/ca.pem
    openssl pkcs8 -in certs/Logstash/Logstash.key -passin pass:$IPA_ADMIN_PASSWORD -topk8 -nocrypt -out certs/Logstash/Logstash.p8

    docker cp certs/ca/ca.pem \
        logstash:/usr/share/logstash/config/ca.pem
    docker cp certs/Logstash/Logstash.crt \
        logstash:/usr/share/logstash/config/Logstash.crt
    docker cp certs/Logstash/Logstash.p8 \
        logstash:/usr/share/logstash/config/Logstash.key
    docker restart logstash
################################################################################
# INSTALL: ElasticSearch Master Node                                           #
################################################################################
    docker run --restart=always -itd --name es -h es.$DOMAIN \
                --network="databridge" \
                --ip 172.18.0.$(echo $ES_IP | awk -F . '{print $4}') \
                -p $ES_IP:9200:9200 \
                -p $ES_IP:9300:9300 \
                -e ES_JAVA_OPTS="-Xms$ES_RAM -Xmx$ES_RAM" \
                -e ELASTIC_PASSWORD="changeme" \
                elasticsearch

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3

    docker exec -itu root es mkdir -p /usr/share/elasticsearch/config/x-pack
    docker exec -itu root es chown elasticsearch:root /usr/share/elasticsearch/config/x-pack
    sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" \
                -e "s/IPAPASS/$IPA_ADMIN_PASSWORD/g" \
                -e "s/IPA_IP/$IPA_IP/g" \
                -e "s/SSLKEYPASS/$IPA_ADMIN_PASSWORD/g" \
                -e "s/ES_IP/$ES_IP/g" \
                -i elasticsearch/elasticsearch.yml
    docker cp elasticsearch/elasticsearch.yml \
        es:/usr/share/elasticsearch/config/elasticsearch.yml
    sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" -i elasticsearch/role_mapping.yml
    docker exec -itu root es mkdir -p /usr/share/elasticsearch/config/x-pack
    docker cp elasticsearch/role_mapping.yml \
        es:/usr/share/elasticsearch/config/role_mapping.yml
    docker cp certs/CozyMaster/CozyMaster.key \
        es:/usr/share/elasticsearch/config/x-pack/CozyMaster.key
    docker cp certs/CozyMaster/CozyMaster.crt \
        es:/usr/share/elasticsearch/config/x-pack/CozyMaster.crt
    docker cp certs/ca/ca.crt \
        es:/usr/share/elasticsearch/config/x-pack/ca.crt
    fi
################################################################################
# INSTALL: ElasticSearch Search Node                                           #
################################################################################
    if $IS_ELK_SEARCH_NOTE; then
    bash scripts/interface.sh $ANALYST_INTERFACE $ESSEARCH_IP $(($(ls /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE:* | wc -l) + 1))
    docker run --restart=always -itd --name essearch -h essearch.$DOMAIN \
                --network="databridge" \
                --ip 172.18.0.$(echo $ESSEARCH_IP | awk -F . '{print $4}') \
                -p $ESSEARCH_IP:9200:9200 \
                -p $ESSEARCH_IP:9300:9300 \
                -e ES_JAVA_OPTS="-Xms$ES_RAM -Xmx$ES_RAM" \
                -e ELASTIC_PASSWORD="changeme" \
                elasticsearch

    # Fixes a memory assignemnt issue I still don't completely understand.
    sysctl vm.drop_caches=3

    docker exec -itu root essearch mkdir -p /usr/share/elasticsearch/config/x-pack
    docker exec -itu root essearch chown elasticsearch:root /usr/share/elasticsearch/config/x-pack
    sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" \
                -e "s/IPAPASS/$IPA_ADMIN_PASSWORD/g" \
                -e "s/LOCALDOMAIN/$DOMAIN/g" \
                -e "s/SSLKEYPASS/$IPA_ADMIN_PASSWORD/g" \
                -e "s/IPA_IP/$IPA_IP/g" \
                -e "s/ES_IP/$ESSEARCH_IP/g" \
                -i elasticsearch/elasticsearch_search.yml
    docker cp elasticsearch/elasticsearch_search.yml \
        essearch:/usr/share/elasticsearch/config/elasticsearch.yml
    sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" -i elasticsearch/role_mapping.yml
    docker cp elasticsearch/role_mapping.yml \
        essearch:/usr/share/elasticsearch/config/role_mapping.yml
    docker cp certs/CozySearch/CozySearch.key \
        essearch:/usr/share/elasticsearch/config/x-pack/CozySearch.key
    docker cp certs/CozySearch/CozySearch.crt \
        essearch:/usr/share/elasticsearch/config/x-pack/CozySearch.crt
    docker cp certs/ca/ca.crt \
        essearch:/usr/share/elasticsearch/config/x-pack/ca.crt

    docker restart es essearch
    fi
################################################################################
# INSTALL: ElasticSearch Data Node(s)                                          #
################################################################################
    if $IS_ELK_DATA_NOTE; then
    COUNTER=0
    while [ $COUNTER -lt $ES_DATA_NODES ]; do
        TMP_IP=$(echo $ESDATA_IP | cut -d. -f1-3).$(($(echo $ESDATA_IP | cut \
            -d. -f4)+$COUNTER))
        bash scripts/interface.sh $ANALYST_INTERFACE $TMP_IP $(($(ls /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE:* | wc -l) + 1))
        docker run --restart=always -itd --name esdata$COUNTER \
                    -h esdata$COUNTER.$DOMAIN \
                    --network="databridge" \
                    --ip 172.18.0.$(echo $TMP_IP | awk -F . '{print $4}') \
                    -p $TMP_IP:9200:9200 \
                    -p $TMP_IP:9300:9300 \
                    -e ES_JAVA_OPTS="-Xms$ES_RAM -Xmx$ES_RAM" \
                    -e ELASTIC_PASSWORD="changeme" \
                    elasticsearch

        # Fixes a memory assignemnt issue I still don't completely understand.
        sysctl vm.drop_caches=3

        docker exec -itu root esdata$COUNTER mkdir -p /usr/share/elasticsearch/config/x-pack
        docker exec -itu root esdata$COUNTER chown elasticsearch:root /usr/share/elasticsearch/config/x-pack
        cp elasticsearch/elasticsearch_data.yml tmp.yml
        sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" \
                    -e "s/NUMBER/$COUNTER/g" \
                    -e "s/IPAPASS/$IPA_ADMIN_PASSWORD/g" \
                    -e "s/SSLKEYPASS/$IPA_ADMIN_PASSWORD/g" \
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
            esdata$COUNTER:/usr/share/elasticsearch/config/role_mapping.yml

        docker cp certs/CozyMaster/CozyMaster.key \
            esdata$COUNTER:/usr/share/elasticsearch/config/x-pack/CozyData$COUNTER.key
        docker cp certs/CozyMaster/CozyMaster.crt \
            esdata$COUNTER:/usr/share/elasticsearch/config/x-pack/CozyData$COUNTER.crt
        docker cp certs/ca/ca.crt \
            esdata$COUNTER:/usr/share/elasticsearch/config/x-pack/ca.crt
        docker restart esdata$COUNTER
      let COUNTER=$COUNTER+1
    done
    fi
################################################################################
# INSTALL: Kibana                                                              #
################################################################################
    if $IS_ELK_SEARCH_NOTE; then
    bash scripts/interface.sh $ANALYST_INTERFACE $KIBANA_IP $(($(ls /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE:* | wc -l) + 1))
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
    PROXYPORTS=$PROXYPORTS"-p $KIBANA_IP:80:80 -p $KIBANA_IP:443:443 "
    fi
fi

if $ENABLE_SPLUNK; then
################################################################################
# INSTALL: BusyBox for Splunk Enterprise                                       #
################################################################################
    bash scripts/interface.sh $ANALYST_INTERFACE $SPLUNK_IP $(($(ls /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE:* | wc -l) + 1))
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
    PROXYPORTS=$PROXYPORTS"-p $SPLUNK_IP:80:80 -p $SPLUNK_IP:443:443 "
fi

if $IS_ELK_DATA_NOTE || $ENABLE_SPLUNK; then
################################################################################
# INSTALL: NGINX Reverse Proxy                                                 #
################################################################################
# Create the reverse proxy
docker run --restart=always -itd --name dataproxy -h dataproxy.$DOMAIN \
            --ip 172.18.0.51 \
            --network="databridge" \
            $(echo $PROXYPORTS) \
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
fi

if $ENABLE_ELK; then
# Automate the Kibana Index Choosing
curl -k -u $IPA_USERNAME:$IPA_ADMIN_PASSWORD -XPUT https://es.$DOMAIN:9200/.kibana/index-pattern/logstash-* -d '{"title" : "logstash-*",  "timeFieldName": "ts"}'
curl -k -u $IPA_USERNAME:$IPA_ADMIN_PASSWORD -XPUT https://es.$DOMAIN:9200/.kibana/config/4.1.1 -d '{"defaultIndex" : "logstash-*"}'
fi
