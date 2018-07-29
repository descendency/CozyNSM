if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

if [ $(docker images | grep elasticsearch | wc -l) -eq 0 ]; then
    echo "Elasticsearch Docker Image not loaded."
    exit 1
fi

TYPE=$(echo $1 | awk '{print tolower($0)}')
INTERFACE=$3
ES_RAM=$4
IPA_ADMIN_PASSWORD=$6
IPA_IP=$5

if [ \( $TYPE != master \) -a \( $TYPE != data \) -a \( $TYPE != search \) ]; then
    echo "acceptable types are \"master\", \"search\", or \"data\"."
    exit 1
fi

if [ $TYPE = master ]; then
	NODE_NAME="CozyMaster"
	NODE_IP=$2
	IS_MASTER=true
	IS_INGEST=true
	IS_DATA=false
fi

if [ $TYPE = search ]; then
	NODE_NAME="CozySearch"
	NODE_IP=$2
	IS_MASTER=false
	IS_INGEST=false
	IS_DATA=false
fi

if [ $TYPE = data ]; then
	NODE_NAME="CozyData"$(docker ps -a | grep cozydata | wc -l | tr -d '[:space:]')
	NODE_IP=$2
	IS_MASTER=false
	IS_INGEST=true
	IS_DATA=true
fi

CONTAINER_NAME=$(echo $NODE_NAME | awk '{print tolower($0)}')

bash scripts/interface.sh $INTERFACE $NODE_IP
if (($(hostname | grep -o "\." | wc -l) > 1)); then DOMAIN=$(echo `hostname` | sed 's/^[^\.]*\.//g'); else read -p "Domain? " DOMAIN; fi
docker run --restart=always -itd --name $CONTAINER_NAME -h $CONTAINER_NAME.$DOMAIN \
            --network="databridge" \
            --ip 172.18.0.$(echo $NODE_IP | awk -F . '{print $4}') \
            -p $NODE_IP:9200:9200 \
            -p $NODE_IP:9300:9300 \
            -e ES_JAVA_OPTS="-Xms$ES_RAM -Xmx$ES_RAM" \
            -e ELASTIC_PASSWORD="$IPA_ADMIN_PASSWORD" \
            elasticsearch

# Fixes a memory assignemnt issue I still don't completely understand.
sysctl vm.drop_caches=3

docker exec -itu root $CONTAINER_NAME mkdir -p /usr/share/elasticsearch/config/x-pack
docker exec -itu root $CONTAINER_NAME chown elasticsearch:root /usr/share/elasticsearch/config/x-pack
cp elasticsearch/elasticsearch_template.yml elasticsearch/tmp.yml
sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" \
            -e "s/IPAPASS/$IPA_ADMIN_PASSWORD/g" \
            -e "s/LOCALDOMAIN/$DOMAIN/g" \
            -e "s/SSLKEYPASS/$IPA_ADMIN_PASSWORD/g" \
            -e "s/IPA_IP/$IPA_IP/g" \
			-e "s/ES_IS_MASTER/$IS_MASTER/g" \
			-e "s/ES_IS_DATA/$IS_DATA/g" \
			-e "s/ES_IS_INGEST/$IS_INGEST/g" \
			-e "s/ES_NAME/$NODE_NAME/g" \
            -e "s/ES_IP/$NODE_IP/g" \
			-i elasticsearch/tmp.yml
docker cp elasticsearch/tmp.yml \
    $CONTAINER_NAME:/usr/share/elasticsearch/config/elasticsearch.yml
rm -f elasticsearch/tmp.yml
sed -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" -i elasticsearch/role_mapping.yml
docker cp elasticsearch/role_mapping.yml \
    $CONTAINER_NAME:/usr/share/elasticsearch/config/role_mapping.yml
docker cp certs/CozyMaster/CozyMaster.key \
    $CONTAINER_NAME:/usr/share/elasticsearch/config/x-pack/$NODE_NAME.key
docker cp certs/CozyMaster/CozyMaster.crt \
    $CONTAINER_NAME:/usr/share/elasticsearch/config/x-pack/$NODE_NAME.crt
docker cp certs/ca/ca.crt \
    $CONTAINER_NAME:/usr/share/elasticsearch/config/x-pack/ca.crt

docker restart $CONTAINER_NAME
