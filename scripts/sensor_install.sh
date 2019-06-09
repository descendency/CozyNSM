# Creating directories ahead of install for scripted ELK configuration.
#mkdir -p /data/bro/current
mkdir -p /data/bro/spool
mkdir -p /data/suricata

################################################################################
# INSTALL: Bro NSM                                                             #
################################################################################
if $ENABLE_BRO; then
    ip link set dev $COLLECTION_INTERFACE promisc on
    ifup $COLLECTION_INTERFACE
    BRO_DIR=/usr/share
    # Configure Bro to run in clustered mode.
    cp bro/etc/node.cfg /etc/bro/node.cfg
    # Configure the number of nodes for Bro.
    echo lb_method=custom >> /etc/bro/node.cfg
    echo lb_procs=$BRO_WORKERS >> /etc/bro/node.cfg
    CPUS=""
    COUNTER=0
    while [ $COUNTER -lt $BRO_WORKERS ]; do
        let COUNTER=COUNTER+1
        if [ $COUNTER -ne $BRO_WORKERS ]; then
            CPUS=$CPUS$COUNTER,
        else
            CPUS=$CPUS$COUNTER
        fi
    done
    echo pin_cpus=$CPUS >> /etc/bro/node.cfg
    echo af_packet_fanout_id=23 >> /etc/bro/node.cfg
    echo af_packet_fanout_mode=AF_Packet::FANOUT_HASH >> /etc/bro/node.cfg
    echo af_packet_buffer_size=128*1024*1024 >> /etc/bro/node.cfg

    # Configure the interface to listen on.
    sed -e "s/INTERFACE/$COLLECTION_INTERFACE/g" -i /etc/bro/node.cfg
    # Configure the BroCTL to have a temporary in-place sensor setup.
    cp bro/etc/broctl.cfg /etc/bro/broctl.cfg
    # Disable certain logs and output in JSON.
    cp bro/etc/local.bro $BRO_DIR/bro/site/local.bro
################################################################################
# DEPLOY: Bro NSM                                                              #
################################################################################
    #ln -s $BRO_DIR/bro/bin/bro /usr/bin/bro
    #ln -s $BRO_DIR/bro/bin/broctl /usr/bin/broctl
    broctl install
    broctl deploy
    broctl stop
    cp bro/etc/bro.service /etc/systemd/system
    # Create CozyStack installed event.
    echo "{\"ts\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"source\":\"Install Script\", \"message\": \"CozyStack installed. This is needed for ELK to initialize correctly.\"}" > /data/bro/current/cozy.log
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
    /usr/bin/stenokeys.sh stenographer stenographer
    systemctl enable stenographer
    systemctl start stenographer
fi
################################################################################
# INSTALL: FileBeat                                                            #
################################################################################
if $ENABLE_ELK; then
    if $ENABLE_XPACK; then
        sed -i -e "s/SSLKEYPASS/$IPA_ADMIN_PASSWORD/g" filebeat/filebeat.yml
        cp filebeat/filebeat.yml /etc/filebeat/filebeat.yml
        cp certs/FileBeat/FileBeat.crt /etc/filebeat/FileBeat.crt
        cp certs/ca/ca.crt /etc/filebeat/ca.crt
        cp certs/FileBeat/FileBeat.key /etc/filebeat/FileBeat.key
    else
        cp filebeat/filebeat_noxpack.yml /etc/filebeat/filebeat.yml
    fi
    systemctl enable filebeat
    systemctl restart filebeat
fi

if $ENABLE_SPLUNK; then
    mkdir -p /data/splunk/var
    mkdir -p /data/splunk/etc

    docker load -i images/universalforwarder.docker
    docker network create --driver=bridge --subnet=172.20.0.0/24 --gateway=172.20.0.1 --ipv6 --subnet=2001:3200:3202::/64 --gateway=2001:3200:3202::1 sensorbridge


    docker run --restart=always -d --name forwarder \
        -e "SPLUNK_START_ARGS=--accept-license" \
        -e SPLUNK_FORWARD_SERVER=$SPLUNK_IP:9997 \
        -e "SPLUNK_PASSWORD=$IPA_ADMIN_PASSWORD" \
        -e SPLUNK_USER=root \
        --ip 172.20.0.100 \
        --ip6="2001:3200:3202::1337" \
        --network="sensorbridge" \
        -p $SENSOR_IP:8088:8088 \
        -p $SENSOR_IP:8089:8089 \
        -p $SENSOR_IP:9997:9997 \
        -v /data:/data:ro \
        universalforwarder

    docker restart forwarder

    sleep 60

    docker exec -itu splunk forwarder /opt/splunkforwarder/bin/splunk add forward-server $SPLUNK_IP:9997 -auth "admin:$IPA_ADMIN_PASSWORD"
    docker exec -itu splunk forwarder /opt/splunkforwarder/bin/splunk set deploy-poll $SPLUNK_IP:8089 -auth "admin:$IPA_ADMIN_PASSWORD"
    docker exec -itu splunk forwarder /opt/splunkforwarder/bin/splunk add monitor /data/bro/current/\*.log -index bro -auth "admin:$IPA_ADMIN_PASSWORD"
    docker exec -itu splunk forwarder /opt/splunkforwarder/bin/splunk add monitor /data/suricata/eve.json -index suricata -auth "admin:$IPA_ADMIN_PASSWORD"

    docker restart forwarder
fi
