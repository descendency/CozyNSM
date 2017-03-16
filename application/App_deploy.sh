################################################################################
# Configure Variables below to your hardware settings.                         #
################################################################################
ram="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
heap="$(($ram / 976562 / 2))"
if [ "$heap" -gt "31" ]; then
es_heap=31g
echo elasticsearch heap size is $es_heap
else
es_heap=$heap"g"
echo elasticsearch heap size is $es_heap
fi
################################################################################
# END OF USER CONFIGURATION - EDIT BELOW AT YOUR OWN RISK                      #
################################################################################

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


###############CHOOSE INTERFACE FOR DOCKER###############################
read -p "Docker interface? (eth0):" INT
sed -i -E s/NIC/$INT/g ./interface.sh
bash ./interface.sh
echo "net.ipv4.conf.all.forwarding=1" >> /usr/lib/sysctl.d/00-system.conf
echo "vm.max_map_count=1073741824" >> /usr/lib/sysctl.d/00-system.conf
#echo -e "\nnameserver $IP.3\n" >> /etc/resolv.conf

################## INSTALL Elasticsearch ##################
mkdir -p /data/esdata
chmod 755 /data
docker build --tag elasticsearch.cozy ./DockerBuild/elasticsearch/
docker run --restart=always -itd -v /data/esdata:/usr/share/elasticsearch/data \
            --name elasticsearchs -h elasticsearch.$DOMAIN \
            -v /tmp/esdata:/usr/share/elasticsearch/data \
            -p ELASTICADDR:9200:9200 \
            -p ELASTICADDR:9300:9300 \
            -e ES_JAVA_OPTS="-Xms$ES_RAM -Xmx$ES_RAM" \
            elasticsearch.cozy

##################  INSTALL Kibana ##################
docker build --tag kibana.cozy ./DockerBuild/kibana/
docker run --restart=always -itd --name kibana --link elasticsearch:elasticsearch -h kibana.$DOMAIN \
            -p KIBANAADDR:80:5601 \
            kibana.cozy

##################  INSTALL Rancher ##################
docker run --restart=always -itd --name rancher -h rancher.$DOMAIN \
            -p RANCHERADDR:8080:8080 \
            rancher/server

##################  INSTALL GOGS ##################
docker run --restart=always -itd --name gogs -h gogs.$DOMAIN \
            -p GOGSADDR:80:3000 \
            -p GOGSADDR:1022:22 \
            gogs/gogs

##################  INSTALL OpenFire ##################
docker run --restart=always -itd --name chat -h chat.$DOMAIN \
            -p CHATADDR:3478:3478/tcp \
            -p CHATADDR:3479:3479/tcp \
            -p CHATADDR:5222:5222/tcp \
            -p CHATADDR:5223:5223/tcp \
            -p CHATADDR:5229:5229/tcp \
            -p CHATADDR:7070:7070/tcp \
            -p CHATADDR:7443:7443/tcp \
            -p CHATADDR:7777:7777/tcp \
            -p CHATADDR:80:9090/tcp \
            -p CHATADDR:9091:9091/tcp \
            sameersbn/openfire

##################  Install OwnCloud ##################
docker run --restart=always -itd --name owncloud -h owncloud.$DOMAIN \
            -p OWNADDR:80:80 \
            -p OWNADDR:443:443 \
            owncloud
