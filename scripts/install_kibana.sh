if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

if [ $(docker images | grep kibana | wc -l) -eq 0 ]; then
    echo "Elasticsearch Docker Image not loaded."
    exit 1
fi

if [ $# -ne 5 ]; then
    echo "Incorrect number of options specified"
    exit 1
fi

KIBANA_IP=$1
INTERFACE=$2
ES_RAM=$3
IPA_IP=$4
IPA_ADMIN_PASSWORD=$5

if (($(hostname | grep -o "\." | wc -l) > 1)); then DOMAIN=$(echo `hostname` | sed 's/^[^\.]*\.//g'); else read -p "Domain? " DOMAIN; fi

bash scripts/install_elasticsearch.sh search $KIBANA_IP $INTERFACE $ES_RAM $IPA_IP $IPA_ADMIN_PASSWORD


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
