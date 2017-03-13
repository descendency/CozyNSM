################################################################################
# Configure Variables below to your hardware settings.                         #
################################################################################
# Name of your domain
DOMAIN=<Domain>

# First 3 octects of the Application server IP
IP=<IP>

# IPA Administator password
IPAPASS=<Password>

# Primary communication interface between the Sensor and Application Servers
# This may be a bonded interface.
INTERFACE=<>

# Heap Space Allocation for Elasticsearch
#ES_RAM=30g    # 30GiB Heap Space for Elasticsearch (For Servers)
ES_RAM=2g     # 2GiB Heap Space for Elasticsearch (For VMs)

# IP Schema
IPA_IP=$IP.3
ES_IP=$IP.7
KIBANA_IP=$IP.8
RANCHER_IP=$IP.9
RANCHER_AGENT_IP=$IP.10
OWNCLOUD_IP=$IP.11
GOGS_IP=$IP.12
CHAT_IP=$IP.13
MATTER_IP=$IP.14
################################################################################
# END OF USER CONFIGURATION - EDIT BELOW AT YOUR OWN RISK                      #
################################################################################
tar xzvf apps.tar.gz

# Install docker (and other RPMs)
yum -y localinstall ./extras/*
yum -y localinstall ./docker/*

# Start docker service
systemctl enable docker
systemctl start docker
docker load -i ./images/rancher-agentv1.1.0.docker
docker load -i ./images/elasticsearch.docker
docker load -i ./images/kibana.docker
docker load -i ./images/rancher.docker
docker load -i ./images/Gogs.docker
docker load -i ./images/openfire.docker
docker load -i ./images/owncloud.docker
docker load -i ./images/logstash.docker
#docker load -i ./images/mattermost.docker
#docker load -i ./images/osticket.docker
#docker load -i ./images/mysql.docker

echo "net.ipv4.conf.all.forwarding=1" >> /usr/lib/sysctl.d/00-system.conf
echo "vm.max_map_count=1073741824" >> /usr/lib/sysctl.d/00-system.conf
echo -e "\nnameserver $IP.3\n" >> /etc/resolv.conf

################## INSTALL Elasticsearch ##################
bash interface.sh $INTERFACE $ES_IP 0
mkdir -p /data/elasticsearch
chmod 766 /data/*
mkdir /tmp/es
chmod 766 /tmp/es
cp elasticsearch/elasticsearch.yml /data/elasticsearch
perl -pi -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" /data/elasticsearch/elasticsearch.yml
perl -pi -e "s/IPAPASS/$IPAPASS/g" /data/elasticsearch/elasticsearch.yml
cp elasticsearch/x-pack-5.1.1.zip /tmp/es
cp elasticsearch/role_mapping.yml /data/elasticsearch/role_mapping.yml
perl -pi -e "s/IPADOMAIN/dc=${DOMAIN//\./,dc=}/g" /data/elasticsearch/role_mapping.yml
docker run --restart=always -itd --name es -h es.$DOMAIN \
            -v /data/elasticsearch/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml \
            -v /data/elasticsearch/data:/usr/share/elasticsearch/data \
            -v /data/elasticsearch/role_mapping.yml:/usr/share/elasticsearch/config/x-pack/role_mapping.yml \
            -v /tmp/es:/tmp/es:z \
            -p $ES_IP:9200:9200 \
            -p $ES_IP:9300:9300 \
            -e ES_JAVA_OPTS="-Xms$ES_RAM -Xmx$ES_RAM" \
            elasticsearch

##################  INSTALL Kibana ##################
bash interface.sh $INTERFACE $KIBANA_IP 1
mkdir -p /data/kibana
chmod 766 /data/*
cp kibana/kibana.yml /data/kibana
cp elasticsearch/x-pack-5.1.1.zip /tmp/es
docker run --restart=always -itd --name kibana -h kibana.$DOMAIN \
            -v /data/kibana/kibana.yml:/etc/kibana/kibana.yml \
            -v /tmp/es:/tmp/es:z \
            -p $KIBANA_IP:80:5601 \
            kibana

##################  INSTALL Rancher ##################
bash interface.sh $INTERFACE $RANCHER_IP 2
bash interface.sh $INTERFACE $RANCHER_AGENT_IP 3
docker run --restart=always -itd --name rancher -h rancher.$DOMAIN \
            -p $RANCHER_IP:80:8080 \
            rancher/server

##################  INSTALL GOGS ##################
bash interface.sh $INTERFACE $GOGS_IP 4
docker run --restart=always -itd --name gogs -h gogs.$DOMAIN \
            -p $GOGS_IP:80:3000 \
            -p $GOGS_IP:1022:22 \
            gogs/gogs

##################  INSTALL OpenFire ##################
bash interface.sh $INTERFACE $CHAT_IP 5
docker run --restart=always -itd --name chat -h chat.$DOMAIN \
            -p $CHAT_IP:3478:3478/tcp \
            -p $CHAT_IP:3479:3479/tcp \
            -p $CHAT_IP:5222:5222/tcp \
            -p $CHAT_IP:5223:5223/tcp \
            -p $CHAT_IP:5229:5229/tcp \
            -p $CHAT_IP:7070:7070/tcp \
            -p $CHAT_IP:7443:7443/tcp \
            -p $CHAT_IP:7777:7777/tcp \
            -p $CHAT_IP:80:9090/tcp \
            -p $CHAT_IP:9091:9091/tcp \
            sameersbn/openfire

##################  Install OwnCloud ##################
bash interface.sh $INTERFACE $OWNCLOUD_IP 6
docker run --restart=always -itd --name owncloud -h owncloud.$DOMAIN \
            -p $OWNCLOUD_IP:80:80 \
            -p $OWNCLOUD_IP:443:443 \
            owncloud

##################  INSTALL mattermost ##################
#bash interface.sh $INTERFACE $MATTER_IP 7
#docker run --restart=always -itd --name mattermost \
#           -h mattermost.$DOMAIN \
#           -p $MATTER_IP:80:8065 \
#           mattermost/mattermost-preview

# Make Elasticsearch Green Again.
#curl -XPUT "http://elasticsearch:9200/_all/_settings?preserve_existing=false" \
#     -d '{ "index.number_of_replicas" : "0" }'

# Install X-Pack and SSO into Elasticsearch/Kibana
#perl -pi -e "s/#//g" /data/elasticsearch/elasticsearch.yml
#perl -pi -e "s/#//g" /data/kibana/kibana.yml
#echo y | docker exec -i es /usr/share/elasticsearch/bin/elasticsearch-plugin \
#                        install file:///tmp/es/x-pack-5.1.1.zip
#docker exec -itu root kibana /usr/share/kibana/bin/kibana-plugin \
#            install file:///tmp/es/x-pack-5.1.1.zip

# Reboot after install finishes
init 6
