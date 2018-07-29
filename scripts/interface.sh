# interface.sh
#
# This script creates virtual interfaces.
#
# Usage:
# ./interface.sh <NIC> <IP of virtual interface>

DIR=/etc/sysconfig/network-scripts
GATEWAY=$(echo $2 | awk -F. '{print $1"."$2"."$3".1"}')

NEXT=$(($(ls /etc/sysconfig/network-scripts/ifcfg-$1:* | wc -l) + 1))

touch $DIR/ifcfg-$1:$NEXT
echo -e TYPE=\"Ethernet\" >> $DIR/ifcfg-$1:$NEXT
echo -e BOOTPROTO=\"none\" >> $DIR/ifcfg-$1:$NEXT
echo -e NAME=\"$1:$NEXT\" >> $DIR/ifcfg-$1:$NEXT
cat $DIR/ifcfg-$1 | grep -oP UUID="?(.*)"? >> $DIR/ifcfg-$1:$NEXT
echo -e DEVICE=\"$1:$NEXT\" >> $DIR/ifcfg-$1:$NEXT
echo -e ONBOOT=\"yes\" >> $DIR/ifcfg-$1:$NEXT
echo -e IPADDR=\"$2\" >> $DIR/ifcfg-$1:$NEXT
echo -e PREFIX=\"24\" >> $DIR/ifcfg-$1:$NEXT
echo -e GATEWAY=\"$GATEWAY\" >> $DIR/ifcfg-$1:$NEXT

ifup ifcfg-$1:$NEXT
