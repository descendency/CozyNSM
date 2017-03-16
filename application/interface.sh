INTERFACE=NIC

############### ELASTICSEARCH #######################
cp /etc/sysconfig/network-scripts/ifcfg-$INTERFACE /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:0
sed -i -E "s/BOOTPROTO=\"?([a-Z0-9]*)\"?/BOOTPROTO=\"none\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:0
sed -i -E "s/NAME=\"?([a-Z0-9]*)\"?/NAME=\"\1\:0\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:0
sed -i -E "s/DEVICE=\"?([a-Z0-9]*)\"?/DEVICE=\"\1\:0\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:0
sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"ELASTICADDR\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:0
if test "grep IPADDR -f /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:0 | wc -l" != 0; then echo -e "IPADDR=\"ELASTICADDR\"\nPREFIX=\"24\"\nGATEWAY=\"$GATEWAY_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:0; else sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"ELASTICADDR\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:0; fi

############### KIBANA #######################
cp /etc/sysconfig/network-scripts/ifcfg-$INTERFACE /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:1
sed -i -E "s/BOOTPROTO=\"?([a-Z0-9]*)\"?/BOOTPROTO=\"none\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:1
sed -i -E "s/NAME=\"?([a-Z0-9]*)\"?/NAME=\"\1\:1\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:1
sed -i -E "s/DEVICE=\"?([a-Z0-9]*)\"?/DEVICE=\"\1\:1\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:1
sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"KIBANAADDR\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:1
if test "grep IPADDR -f /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:1 | wc -l" != 0; then echo -e "IPADDR=\"KIBANAADDR\"\nPREFIX=\"24\"\nGATEWAY=\"$GATEWAY_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:1; else sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"KIBANAADDR\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:1; fi

############### Rancher Manager #######################
cp /etc/sysconfig/network-scripts/ifcfg-$INTERFACE /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:2
sed -i -E "s/BOOTPROTO=\"?([a-Z0-9]*)\"?/BOOTPROTO=\"none\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:2
sed -i -E "s/NAME=\"?([a-Z0-9]*)\"?/NAME=\"\1\:2\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:2
sed -i -E "s/DEVICE=\"?([a-Z0-9]*)\"?/DEVICE=\"\1\:2\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:2
sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"RANCHERADDR_IP\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:2
if test "grep IPADDR -f /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:2 | wc -l" != 0; then echo -e "IPADDR=\"RANCHERADDR_IP\"\nPREFIX=\"24\"\nGATEWAY=\"$GATEWAY_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:2; else sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"RANCHERADDR_IP\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:2; fi

############### RANCHER_AGENT #######################
cp /etc/sysconfig/network-scripts/ifcfg-$INTERFACE /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:3
sed -i -E "s/BOOTPROTO=\"?([a-Z0-9]*)\"?/BOOTPROTO=\"none\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:3
sed -i -E "s/NAME=\"?([a-Z0-9]*)\"?/NAME=\"\1\:3\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:3
sed -i -E "s/DEVICE=\"?([a-Z0-9]*)\"?/DEVICE=\"\1\:3\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:3
sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"RANCHERADDR_AGENT_IP\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:3
if test "grep IPADDR -f /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:3 | wc -l" != 0; then echo -e "IPADDR=\"RANCHERADDR_AGENT_IP\"\nPREFIX=\"24\"\nGATEWAY=\"$GATEWAY_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:3; else sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"RANCHERADDR_AGENT_IP\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:3; fi

############### Owncloud #######################
cp /etc/sysconfig/network-scripts/ifcfg-$INTERFACE /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:4
sed -i -E "s/BOOTPROTO=\"?([a-Z0-9]*)\"?/BOOTPROTO=\"none\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:4
sed -i -E "s/NAME=\"?([a-Z0-9]*)\"?/NAME=\"\1\:4\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:4
sed -i -E "s/DEVICE=\"?([a-Z0-9]*)\"?/DEVICE=\"\1\:4\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:4
sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"OWNADDR\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:4
if test "grep IPADDR -f /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:4 | wc -l" != 0; then echo -e "IPADDR=\"OWNADDR\"\nPREFIX=\"24\"\nGATEWAY=\"$GATEWAY_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:4; else sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"OWNADDR\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:4; fi

############### GOGS #######################
cp /etc/sysconfig/network-scripts/ifcfg-$INTERFACE /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:5
sed -i -E "s/BOOTPROTO=\"?([a-Z0-9]*)\"?/BOOTPROTO=\"none\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:5
sed -i -E "s/NAME=\"?([a-Z0-9]*)\"?/NAME=\"\1\:5\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:5
sed -i -E "s/DEVICE=\"?([a-Z0-9]*)\"?/DEVICE=\"\1\:5\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:5
sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"GOGSADDR\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:5
if test "grep IPADDR -f /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:5 | wc -l" != 0; then echo -e "IPADDR=\"GOGSADDR\"\nPREFIX=\"24\"\nGATEWAY=\"$GATEWAY_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:5; else sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"GOGSADDR\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:5; fi

############### CHAT #######################
cp /etc/sysconfig/network-scripts/ifcfg-$INTERFACE /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:6
sed -i -E "s/BOOTPROTO=\"?([a-Z0-9]*)\"?/BOOTPROTO=\"none\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:6
sed -i -E "s/NAME=\"?([a-Z0-9]*)\"?/NAME=\"\1\:6\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:6
sed -i -E "s/DEVICE=\"?([a-Z0-9]*)\"?/DEVICE=\"\1\:6\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:6
sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"CHATADDR\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:6
if test "grep IPADDR -f /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:6 | wc -l" != 0; then echo -e "IPADDR=\"CHATADDR\"\nPREFIX=\"24\"\nGATEWAY=\"$GATEWAY_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:6; else sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"CHATADDR\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:6; fi

############### CUCKOO #######################
cp /etc/sysconfig/network-scripts/ifcfg-$INTERFACE /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:7
sed -i -E "s/BOOTPROTO=\"?([a-Z0-9]*)\"?/BOOTPROTO=\"none\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:7
sed -i -E "s/NAME=\"?([a-Z0-9]*)\"?/NAME=\"\1\:7\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:7
sed -i -E "s/DEVICE=\"?([a-Z0-9]*)\"?/DEVICE=\"\1\:7\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:7
sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"CUCKOOADDR\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:7
if test "grep IPADDR -f /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:7 | wc -l" != 0; then echo -e "IPADDR=\"$CUCKOOADDR\"\nPREFIX=\"24\"\nGATEWAY=\"$GATEWAY_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:7; else sed -i -E "s/IPADDR=\"?([0-9\.]*)\"?/IPADDR=\"$MATTERMOST_IP\"/g" /etc/sysconfig/network-scripts/ifcfg-$INTERFACE:7; fi
