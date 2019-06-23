# install_elasticsearch name containername ip masterIP
NAME=$1
CONTAINERNAME=$2
TMP_ES_IP=$3
ES_IP=$4

if [ $CONTAINERNAME == "elasticsearch_data" ]; then
    NUMBER=$(docker ps -a | grep elasticsearch_data | wc -l)
    cp elasticsearch/elasticsearch_data.yml elasticsearch/elasticsearch_data$NUMBER.yml
    CONTAINERNAME=$CONTAINERNAME$NUMBER
fi

docker run --restart=always -itd --name $CONTAINERNAME -h $NAME.$DOMAIN \
            --network="databridge" \
            --ip 172.18.0.$(echo $TMP_ES_IP | awk -F . '{print $4}') \
            -p $TMP_ES_IP:9200:9200 \
            -p $TMP_ES_IP:9300:9300 \
            -e ES_JAVA_OPTS="-Xms$ES_RAM -Xmx$ES_RAM" \
            elasticsearch

# Fixes a memory assignemnt issue I still don't completely understand.
sysctl vm.drop_caches=3
docker cp elasticsearch/elasticsearch_basic.yml $CONTAINERNAME:/usr/share/elasticsearch/config/elasticsearch.yml
docker restart $CONTAINERNAME
echo $IPA_ADMIN_PASSWORD | docker exec -i $CONTAINERNAME /bin/bash -c "cat | bin/elasticsearch-keystore add --stdin xpack.security.transport.ssl.keystore.secure_password"
echo $IPA_ADMIN_PASSWORD | docker exec -i $CONTAINERNAME /bin/bash -c "cat | bin/elasticsearch-keystore add --stdin xpack.security.transport.ssl.truststore.secure_password"
echo $IPA_ADMIN_PASSWORD | docker exec -i $CONTAINERNAME /bin/bash -c "cat | bin/elasticsearch-keystore add --stdin xpack.security.http.ssl.keystore.secure_password"
echo $IPA_ADMIN_PASSWORD | docker exec -i $CONTAINERNAME /bin/bash -c "cat | bin/elasticsearch-keystore add --stdin xpack.security.http.ssl.truststore.secure_password"
echo $IPA_ADMIN_PASSWORD | docker exec -i $CONTAINERNAME /bin/bash -c "cat | bin/elasticsearch-keystore add --stdin xpack.security.http.ssl.secure_key_passphrase"
echo $IPA_ADMIN_PASSWORD | docker exec -i $CONTAINERNAME /bin/bash -c "cat | bin/elasticsearch-keystore add --stdin xpack.security.transport.ssl.secure_key_passphrase"
echo $IPA_ADMIN_PASSWORD | docker exec -i $CONTAINERNAME /bin/bash -c "cat | bin/elasticsearch-keystore add --stdin xpack.security.authc.realms.ldap.ldap1.secure_bind_password"

docker exec -u root $CONTAINERNAME mkdir config/certs
docker exec -u root $CONTAINERNAME chown elasticsearch:elasticsearch config/certs
docker cp certs/Elasticsearch/Elasticsearch.key $CONTAINERNAME:/usr/share/elasticsearch/config/certs/elasticsearch.key
docker exec -u root $CONTAINERNAME chown elasticsearch:elasticsearch /usr/share/elasticsearch/config/certs/elasticsearch.key
docker cp certs/Elasticsearch/Elasticsearch.crt $CONTAINERNAME:/usr/share/elasticsearch/config/certs/elasticsearch.crt
docker exec -u root $CONTAINERNAME chown elasticsearch:elasticsearch /usr/share/elasticsearch/config/certs/elasticsearch.crt
docker cp certs/ca/ca.crt $CONTAINERNAME:/usr/share/elasticsearch/config/certs/ca.crt
docker exec -u root $CONTAINERNAME chown elasticsearch:elasticsearch /usr/share/elasticsearch/config/certs/ca.crt
sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" \
            -e "s/ES_NAME/$CONTAINERNAME/" \
            -e "s/IPA_USERNAME/$IPA_USERNAME/g" \
            -e "s/IPA_IP/$IPA_IP/g" \
            -e "s/ES_IP/$TMP_ES_IP/g" \
            -e "s/ES_MASTER_IP/$ES_IP/g" \
            -i elasticsearch/$CONTAINERNAME.yml
sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" -i elasticsearch/role_mapping.yml
docker cp elasticsearch/role_mapping.yml \
    $CONTAINERNAME:/usr/share/elasticsearch/config/role_mapping.yml
sed -e "s/ES_MASTER_IP/$ES_IP/g" -e "s/ES_IP/$TMP_ES_IP/g" -i elasticsearch/$CONTAINERNAME.yml
if [ $CONTAINERNAME == "elasticsearch_master" ]; then
    docker stop logstash
    while [ $(docker logs $CONTAINERNAME | tail -25 | grep started | wc -l) -ne 1 ]; do
        sleep 10
    done
    curl -XPOST http://$ES_IP:9200/_xpack/license/start_trial?acknowledge=true
    #docker exec -itu root $CONTAINERNAME sed -i -e 's/#//g' config/elasticsearch.yml
fi
docker cp elasticsearch/$CONTAINERNAME.yml $CONTAINERNAME:/usr/share/elasticsearch/config/elasticsearch.yml
docker restart $CONTAINERNAME
if [ $CONTAINERNAME == "elasticsearch_master" ]; then
    while [ $(docker logs $CONTAINERNAME | tail -25 | grep started | wc -l) -ne 1 ]; do
        sleep 10
    done
    echo garbage > es.output
    while [ "$(cat es.output | grep "PASSWORD elastic =" | wc -l)" -eq "0" ]; do
        docker exec -it $CONTAINERNAME /usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto -b > es.output
        sleep 10
    done
    dos2unix es.output
fi

docker restart $CONTAINERNAME
sleep 60
while [ $(docker logs $CONTAINERNAME | tail -25 | grep started | wc -l) -eq 0 ]; do
    if [ $CONTAINERNAME != "elasticsearch_master" ]; then
        docker exec -itu root $CONTAINERNAME /bin/bash -c "rm -rf /usr/share/elasticsearch/data/*"
    fi
    docker restart $CONTAINERNAME
    sleep 60
done
