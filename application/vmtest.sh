################################################################################
# Configure Variables below to your hardware settings.
################################################################################

# Base directory where the logs and pcap should be stored.
HOME_DIR=/data/

# Domain to be used for Cozy Stack installation.
DOMAIN=<Domain>

################################################################################
# END OF USER CONFIGURATION - EDIT BELOW AT YOUR OWN RISK
################################################################################
service firewalld stop
# Install docker (and other RPMs)
yum localinstall -y ./extras/*
yum localinstall -y ./docker/*

# Create Virtual interfaces for containers.
#bash interface.sh
#systemctl restart network

# Start docker service
systemctl enable docker
systemctl start docker
docker load -i ./images/rancher-agentv1.0.0.docker
docker load -i ./images/elasticsearch.docker
docker load -i ./images/kibana.docker
docker load -i ./images/rancher.docker
docker load -i ./images/Gogs.docker
docker load -i ./images/openfire.docker
docker load -i ./images/owncloud.docker
docker load -i ./images/mattermost.docker
docker load -i ./images/osticket.docker
docker load -i ./images/mysql.docker
mkdir -p $HOME_DIR

sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -w vm.max_map_count=1073741824


################## INSTALL Elasticsearch ##################
docker run --restart=always -itd --name es -h es.$DOMAIN -p 9200:9200 -p $ES_IP:9300:9300 -e ES_JAVA_OPTS="-Xms22g -Xmx30g" elasticsearch

################### INSTALL Kibana ########################
docker run --restart=always -it --name kibana -h kibana.$DOMAIN --link es:elasticsearch -p 5601:5601 -d kibana

################### INSTALL Rancher #######################
docker run --restart=always -it -d --name rancher -h rancher.$DOMAIN -p 1080:8080 rancher/server

################### INSTALL GOGS #######################
docker run --name gogs -h gogs.$DOMAIN -it -d --restart=always -p 3000:3000 -p 1022:22 gogs/gogs

################### INSTALL OpenFire ######################
docker run -it -d --restart=always --name=chat -h chat.$DOMAIN -p 3478:3478/tcp -p 3479:3479/tcp -p 5222:5222/tcp -p 5223:5223/tcp -p 5229:5229/tcp -p 7070:7070/tcp -p 7443:7443/tcp -p 7777:7777/tcp -p 9090:9090/tcp -p 9091:9091/tcp sameersbn/openfire

################### Install OwnCloud ######################
docker run --name owncloud -h owncloud.$DOMAIN --restart=always -it -d -p 2080:80 -p 4443:443 owncloud

################### INSTALL mattermost #######################
docker run --restart=always -it -d --name mattermost -h mattermost.$DOMAIN -p 8065:8065 mattermost/mattermost-preview
