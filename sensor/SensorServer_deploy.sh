################################################################################
# Configure Variables below to your hardware settings.                         #
################################################################################
# For setting up collection interface (ex: eth0)
INTERFACE=<name of collection interface>

# Network portion of the IP address (ex: 192.168.1.x)
IP=<first 3 octects of your ip schema>

# The name of the domain (ex: $DOMAIN)
DOMAIN=<domain name>

# Default IPA Administrator password.
IPA_ADMIN_PASSWORD=<>

# Number of Bro workers to process traffic.
BRO_WORKERS=2      # For VMs
#BRO_WORKERS=40     # For Servers

#IP Schema
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
# EDIT BELOW AT YOUR OWN RISK                                                  #
################################################################################
tar xzvf sensor.tar.gz

echo -e $ES_IP\\telasticsearch >> /etc/hosts
# Install IPA
yum -y localinstall rpm/logstash/*.rpm # packages needed for freeIPA aswell as logstash
yum -y localinstall rpm/freeipa/*.rpm
ipa-server-install -U \
  -r $DOMAIN \
  -n $DOMAIN \
  -p $IPA_ADMIN_PASSWORD \
  -a toortoor \
  --mkhomedir \
  --setup-dns \
  --no-forwarders \
  --reverse-zone=$(echo $ES_IP | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
systemctl enable ipa
systemctl start ipa

echo $IPA_ADMIN_PASSWORD | kinit admin
ipa dnsrecord-add $DOMAIN ipa --a-rec=$IPA_IP
ipa dnsrecord-add $DOMAIN elasticsearch --a-rec=$ES_IP
ipa dnsrecord-add $DOMAIN es --a-rec=$ES_IP
ipa dnsrecord-add $DOMAIN kibana --a-rec=$KIBANA_IP
ipa dnsrecord-add $DOMAIN rancher --a-rec=$RANCHER_IP
ipa dnsrecord-add $DOMAIN owncloud --a-rec=$OWNCLOUD_IP
ipa dnsrecord-add $DOMAIN gogs --a-rec=$GOGS_IP
ipa dnsrecord-add $DOMAIN chat --a-rec=$CHAT_IP
ipa dnsrecord-add $DOMAIN mattermost --a-rec=$MATTER_IP

# Install Bro
yum -y localinstall rpm/base/*.rpm
yum -y localinstall rpm/bro/*.rpm
tar xzvf bro.tar.gz
cd bro/bro-2.5
./configure
make
make install
cd ../..
cd bro/bro-plugins/af_packet
./configure --bro-dist=../../bro-2.5/ --with-kernel=/usr/include
make
make install
cd ../../..
cp bro/etc/node.cfg /usr/local/bro/etc/node.cfg
COUNTER=2
while [  $COUNTER -le $BRO_WORKERS ]; do
  echo [worker-$COUNTER] >> /usr/local/bro/etc/node.cfg
  echo type=worker >> /usr/local/bro/etc/node.cfg
  echo host=localhost >> /usr/local/bro/etc/node.cfg
  echo interface=af_packet::$INTERFACE >> /usr/local/bro/etc/node.cfg
  let COUNTER=COUNTER+1
done
perl -pi -e "s/INTERFACE/$INTERFACE/g" /usr/local/bro/etc/node.cfg
cp bro/etc/broctl.cfg /usr/local/bro/etc/broctl.cfg
cp bro/etc/local.bro /usr/local/bro/share/bro/site/local.bro

# Use BroCTL to finish Bro install and deploy
mkdir -p /data/bro
mkdir -p /data/bro/spool
/usr/local/bro/bin/broctl install
/usr/local/bro/bin/broctl deploy
/usr/local/bro/bin/broctl stop
cp bro/etc/bro.service /etc/systemd/system
systemctl enable bro
systemctl start bro

# Install suricata
tar xzvf suricata.tar.gz
cd suricata/suricata-3.2
./configure --prefix=/usr \
  --sysconfdir=/etc \
  --localstatedir=/var \
  --enable-nfqueue \
  --enable-lua
autoreconf -isvf
ldconfig /usr/local/lib
make
make install-full
cd ../..
cp suricata/etc/suricata.yaml /etc/suricata/suricata.yaml
perl -pi -e "s/DEVICENAME/$INTERFACE/g" /etc/suricata/suricata.yaml
ethtool -K $INTERFACE lro off
ethtool -K $INTERFACE gro off
ldconfig /usr/local/lib
cp suricata/suricata.service /etc/systemd/system
perl -pi -e "s/INTERFACE/$INTERFACE/g" /etc/systemd/system/suricata.service
systemctl enable suricata
systemctl start suricata

#### Extract ET Rules
#### to /etc/suricata/rules

# Install stenographer
yum -y localinstall rpm/stenographer/*.rpm
mkdir -p /data/index
chown stenographer:stenographer /data/index
mkdir -p /data/packets
chown stenographer:stenographer /data/packets
cp stenographer/etc/config /etc/stenographer/config
perl -pi -e "s/placeholder/$INTERFACE/g" /etc/stenographer/config
chmod 755 /etc/stenographer
chown stenographer:stenographer /etc/stenographer/certs
chmod 750 /etc/stenographer/certs
systemctl enable stenographer
systemctl start stenographer

# Install filebeat
yum -y localinstall rpm/filebeat/*.rpm
cp filebeat/filebeat.yml /etc/filebeat/filebeat.yml
systemctl enable filebeat
systemctl start filebeat

# Install Metricbeat
yum -y localinstall rpm/metricbeat/*.rpm
cp metricbeat/metricbeat.yml /etc/metricbeat/metricbeat.yml
systemctl enable metricbeat
systemctl start metricbeat

# Install Logstash
# yum -y localinstall rpm/logstash/*.rpm
mkdir -p /usr/share/GeoIP
cp logstash/GeoLite2-City.mmdb /usr/share/GeoIP
cp logstash/logstash.service /etc/systemd/system
cp logstash/logstash.conf /etc/logstash/conf.d/logstash.conf
cp logstash/logstash.yml /etc/logstash/logstash.yml
mkdir /data/logstash
chmod 777 /data/logstash
systemctl enable logstash
systemctl start logstash

# Restart
init 6
