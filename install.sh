################################################################################
# DO NOT EDIT THIS SCRIPT! Configuration is now handled by the TUI!            #
################################################################################
# Ensure the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi
echo "Starting TUI Installer. Please be patient."
{
# Remove FIPS STIG to allow basically everything to run.
yum -q -e 0 remove -y dracut-fips\*
dracut --force
grubby --update-kernel=ALL --remove-args=fips=1
sed -i 's/ fips=1//' /etc/default/grub

yum --nogpgcheck -y -q -e 0 localinstall rpm/dialog/*.rpm
} > /dev/null 2>&1
bash scripts/rpm_install.sh &
source scripts/install_tui.sh

clear
echo "Installing. This will take some time (30+ minutes)."
while [ $(ps -ef | grep .*rpm_install\.sh.* | wc -l ) -gt 1 ]; do
    sleep 1
done
bash scripts/sensor_rpm_install.sh
bash scripts/setup_networking.sh
if $IS_APP_SERVER; then
    bash scripts/application_install.sh
fi
if $IS_DATASTORE; then
    bash scripts/datastore_install.sh
fi
if $IS_SENSOR; then
    bash scripts/sensor_install.sh
fi
bash scripts/configure_first_user.sh

grub2-set-default 0

mv /etc/sssd/sssd.conf /etc/sssd/sssd.conf.bak
touch /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf
systemctl restart sssd
cat /etc/sssd/sssd.conf.bak > /etc/sssd/sssd.conf
rm -rf /etc/sssd/sssd.conf.bak

# FreeIPA will handle NTP Services. NTPd disabled to stop it from binding ports
if $IS_APP_SERVER; then
    systemctl stop ntpd
    systemctl disable ntpd
fi

init 6
