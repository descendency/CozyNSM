#################################################
#   ____               ____  _             _    #
#  / ___|___ _____   _/ ___|| |_ __ _  ___| | __#
# | |   / _ \_  / | | \___ \| __/ _` |/ __| |/ /#
# | |__| (_) / /| |_| |___) | || (_| | (__|   < #
#  \____\___/___|\__, |____/ \__\__,_|\___|_|\_\#
#                |___/                          #
#################################################
echo "This script will assign variables that will be used throughout the CozyStack Sensor and Application server installation process"


############################################################################################################################
#.-. .-..-. .-..-..-.   .-..----..---.  .----.  .--.  .-.       .-.   .-..--.  .---. .-.  .--.  .----. .-.   .----. .----. #
#| } { ||  \{ |{ | \ \_/ / } |__}} }}_}{ {__-` / {} \ } |        \ \_/ // {} \ } }}_}{ | / {} \ | {_} }} |   } |__}{ {__-` #
#\ `-' /| }\  {| }  \   /  } '__}| } \ .-._} }/  /\  \} '--.      \   //  /\  \| } \ | }/  /\  \| {_} }} '--.} '__}.-._} } #
# `---' `-' `-'`-'   `-'   `----'`-'-' `----' `-'  `-'`----'       `-' `-'  `-'`-'-' `-'`-'  `-'`----' `----'`----'`----'  #
############################################################################################################################
read -p "Domain Name ex.(test.lan): " DOMAIN_NAME
read -p "IP Schema ex.(192.168.1): " IP
read -sp "IPA Administrator password (must be 8 characters in length): " IPA_ADMIN_PASSWORD
echo "IPA admin password set"
read -p "Elasticsearch Username: ": ES_USER
read -sp "Elasticsearch Password: " ES_PASS




##########################################################
#.-..-.-.      .----..----..-. .-..----..-.  .-.  .--.   #
#{ || } }}    { {__-`| }`-'{ {_} |} |__}}  \/  { / {} \  #
#| }| |-'     .-._} }| },-.| { } }} '__}| {  } |/  /\  \ #
#`-'`-'       `----' `----'`-' `-'`----'`-'  `-'`-'  `-' #
##########################################################
IPA_IP=$IP.3
APPLICATION_IP=.4
ES_IP=$IP.7
KIBANA_IP=$IP.8
RANCHER_IP=$IP.9
OWNCLOUD_IP=$IP.10
GOGS_IP=$IP.11
CHAT_IP=$IP.12

sed -i -E s/ELASTICADDR/$ES_IP/g ./Application/App_deploy.sh
sed -i -E s/KIBANAADDR/$KIBANA_IP/g ./Application/App_deploy.sh
sed -i -E s/RANCHERADDR/$RANCHER_IP/g ./Application/App_deploy.sh
sed -i -E s/OWNADDR/$OWNCLOUD_IP/g ./Application/App_deploy.sh
sed -i -E s/GOGSADDR/$GOGS_IP/g ./Application/App_deploy.sh
sed -i -E s/CHATADDR/$CHAT_IP/g ./Application/App_deploy.sh


sed -i -E s/ELASTICADDR/$ES_IP/g ./Application/interface.sh
sed -i -E s/KIBANAADDR/$KIBANA_IP/g ./Application/interface.sh
sed -i -E s/RANCHERADDR/$RANCHER_IP/g ./Application/interface.sh
sed -i -E s/OWNADDR/$OWNCLOUD_IP/g ./Application/interface.sh
sed -i -E s/GOGSADDR/$GOGS_IP/g ./Application/interface.sh
sed -i -E s/CHATADDR/$CHAT_IP/g ./Application/interface.sh






#############################################################################################################################################################################
# ,-----.                                       ,--.       ,---.                                           ,------.                                                         #
#'  .--./,--.,--.,--.--.,--.--. ,---. ,--,--, ,-'  '-.    '   .-'  ,---. ,--.--.,--.  ,--.,---. ,--.--.    |  .--. ' ,---.  ,---.  ,---. ,--.,--.,--.--. ,---. ,---.  ,---. #
#|  |    |  ||  ||  .--'|  .--'| .-. :|      \'-.  .-'    `.  `-. | .-. :|  .--' \  `'  /| .-. :|  .--'    |  '--'.'| .-. :(  .-' | .-. ||  ||  ||  .--'| .--'| .-. :(  .-' #
#'  '--'\'  ''  '|  |   |  |   \   --.|  ||  |  |  |      .-'    |\   --.|  |     \    / \   --.|  |       |  |\  \ \   --..-'  `)' '-' ''  ''  '|  |   \ `--.\   --..-'  `)#
# `-----' `----' `--'   `--'    `----'`--''--'  `--'      `-----'  `----'`--'      `--'   `----'`--'       `--' '--' `----'`----'  `---'  `----' `--'    `---' `----'`----' #
#############################################################################################################################################################################


hostname="$(echo $HOSTNAME)"
ram="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
heap="$(($ram / 976562))"
space="$(df -hT)"
cpu="$(grep -c ^processor /proc/cpuinfo)"
echo "Current Server ($hostname) has $heap Gib of memory"
echo "Current Server ($hostname) storage space:
$space"
echo "Current Server ($hostname) has $cpu CPU cores"




#######################################################################################################
#.----..-..-..-.-.  .---. .---. .-----.    .-.   .-..--.  .---. .-.  .--.  .----. .-.   .----. .----. #
#} |__}\ {} /| } }}/ {-. \} }}_}`-' '-'     \ \_/ // {} \ } }}_}{ | / {} \ | {_} }} |   } |__}{ {__-` #
#} '__}/ {} \| |-' \ '-} /| } \   } {        \   //  /\  \| } \ | }/  /\  \| {_} }} '--.} '__}.-._} } #
#`----'`-'`-'`-'    `---' `-'-'   `-'         `-' `-'  `-'`-'-' `-'`-'  `-'`----' `----'`----'`----'  #
#######################################################################################################

export DOMAIN_NAME IP IPA_ADMIN_PASSWORD IPA_IP ES_IP KIBANA_IP RANCHER_AGENT_IP RANCHER_IP OWNCLOUD_IP GOGS_IP CHAT_IP MATTER_IP
sed -i -E  s/ELASTIC_IP/$ES_IP/g ./Application/DockerBuild/kibana/kibana.yml
sed -i -E  s/ELASTIC_IP/$ES_IP/g ./Application/DockerBuild/elasticsearch/elasticsearch.yml
sed -i -E s/elastic/$ES_USER/g ./Application/DockerBuild/kibana/kibana.yml
sed -i -E s/changeme/$ES_PASS/g ./Application/DockerBuild/kibana/kibana.yml



#####################################################################
#.----. .----..-.-. .-.    .---..-.  .-..-.  .-..----..-. .-..-----.#
#} {-. \} |__}| } }}} |   / {-. \\ \/ / }  \/  {} |__}|  \{ |`-' '-'#
#} '-} /} '__}| |-' } '--.\ '-} / `-\ } | {  } |} '__}| }\  {  } {  #
#`----' `----'`-'   `----' `---'    `-' `-'  `-'`----'`-' `-'  `-'  #
#####################################################################
echo "Would you like to install the Sensor or Application Server?"
OPTIONS="Sensor Application"
select opt in $OPTIONS; do
   if [ "$opt" = "Sensor" ]; then
    echo installing sensor server
    bash ./sensor/script.sh
   elif [ "$opt" = "Application" ]; then
    echo installing application server
    bash ./Application/App_deploy.sh
   else
    clear
    echo bad option
    fi
done
