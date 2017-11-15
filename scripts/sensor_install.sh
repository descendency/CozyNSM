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
    /usr/bin/stenokeys.sh stenographer stenographer
    systemctl enable stenographer
    systemctl start stenographer
fi
################################################################################
# INSTALL: FileBeat                                                            #
################################################################################
    cp filebeat/filebeat.yml /etc/filebeat/filebeat.yml
    cp certs/FileBeat/FileBeat.crt /etc/filebeat/FileBeat.crt
    cp certs/ca/ca.crt /etc/filebeat/ca.crt
    cp certs/FileBeat/FileBeat.key /etc/filebeat/FileBeat.key
    systemctl restart filebeat
