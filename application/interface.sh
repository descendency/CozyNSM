# interface.sh
#
# This script creates virtual interfaces.
#
# Usage:
# ./interface.sh <NIC> <IP of virtual interface> <virtual number>

DIR=/etc/sysconfig/network-scripts
GATEWAY=$(echo $2 | awk -F. '{print $1"."$2"."$3".1"}')

touch $DIR/ifcfg-$1:$3
echo -e TYPE=\"Ethernet\" >> $DIR/ifcfg-$1:$3
echo -e BOOTPROTO=\"none\" >> $DIR/ifcfg-$1:$3
echo -e NAME=\"$1:$3\" >> $DIR/ifcfg-$1:$3
cat $DIR/ifcfg-$1 | grep -oP UUID="?(.*)"? >> $DIR/ifcfg-$1:$3
echo -e DEVICE=\"$1:$3\" >> $DIR/ifcfg-$1:$3
echo -e ONBOOT=\"yes\" >> $DIR/ifcfg-$1:$3
echo -e IPADDR=\"$2\" >> $DIR/ifcfg-$1:$3
echo -e PREFIX=\"24\" >> $DIR/ifcfg-$1:$3
echo -e GATEWAY=\"$GATEWAY\" >> $DIR/ifcfg-$1:$3

ifup ifcfg-$1:$3
