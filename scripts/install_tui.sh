PANE=1
BACKTITLE="CozyStack Install"
export LOCAL_REPO="false"

dialog --backtitle "$BACKTITLE" \
--title "About" \
--msgbox 'This is will install CozyStack. Enjoy.' 10 30

function serverroles () {
    TEXT="There are 3 server roles. Each server type installs a specific set of tools. You may choose 1-3 server roles per server.

    A sensor turns collected network traffic into logs. Typical programs on a sensor are Zeek(Bro), Suricata, Stenographer, Elastic Stack(FileBeat), and Splunk (Forwarder).

    A datastore receives logs from a sensor and indexes them into a database. The two main tools on a datastore are Elastic Stack and Splunk Enterprise.

    There is also a communication server adds a number of programs to aid collaboration. This adds tools like GoGS, RocketChat, OwnCloud, and TheHive with Cortex. This server also contains the FreeIPA server. A server with the 'communication' role MUST be created first. The ipa-client install will fail without it.

    Select the server roles for this server below:"
    CHOICE=`dialog --title "Server Type(s)" --backtitle "$BACKTITLE" --stdout --ok-label Next --cancel-label Quit --checklist "$TEXT" 40 80 3 \
            Sensor "" $(if $IS_SENSOR; then echo on; else echo off; fi) \
            Datastore "" $(if $IS_DATASTORE; then echo on; else echo off; fi) \
            "Communication" "" $(if $IS_APP_SERVER; then echo on; else echo off; fi)`
    RESPONSE=$?
    if [[ $RESPONSE -eq 0 ]]; then
        if [[ $CHOICE == *"Sensor"* ]]; then
                export IS_SENSOR="true"
        else
                export IS_SENSOR="false"
        fi
        if [[ $CHOICE == *"Datastore"* ]]; then
                export IS_DATASTORE="true"
        else
                export IS_DATASTORE="false"
        fi
        if [[ $CHOICE == *"Communication"* ]]; then
                export IS_APP_SERVER="true"
        else
                export IS_APP_SERVER="false"
        fi
        let PANE=2
    else
        let PANE=0
    fi
}

function configureelk () {
    TEXT="Choose which elastic features you want enabled on this server.

    Master Nodes control the flow of data within an Elastic cluster. Every cluster needs at least 1 master node.

    Search nodes have Kibana attached to them and allow Kibana to query the Elastic cluster. Every cluster needs 1 search node (to have access to Kibana).

    Data nodes store the data inside of an elastic cluster. Every cluster needs 1 search node (to store any data).

    X-Pack is a paid set of extensions that provide things like LDAP authentication (SSO), encryption (SSL), and additional Elastic Features."

    OPTIONS=()
    if $IS_DATASTORE; then
        OPTIONS+=("Data" "" $(if $IS_ELK_DATA_NOTE; then echo on; else echo off; fi))
        OPTIONS+=("Search" "" $(if $IS_ELK_SEARCH_NOTE; then echo on; else echo off; fi))
        OPTIONS+=("Master" "" $(if $IS_ELK_MASTER_NOTE; then echo on; else echo off; fi))
    fi
    #if $IS_SENSOR || $IS_DATASTORE; then
    #    OPTIONS+=("X-Pack" "" $(if $ENABLE_XPACK; then echo on; else echo off; fi))
    #fi

    CHOICE=`dialog --title "Elastic Configuration" --backtitle "$BACKTITLE" --stdout --ok-label Next --cancel-label Back --checklist "$TEXT" 40 80 20 \
            "${OPTIONS[@]}"`


    RESPONSE=$?
    if [[ $RESPONSE -eq 0 ]]; then
        if [[ $CHOICE == *"Data"* ]]; then
                export IS_ELK_DATA_NOTE="true"
        else
                export IS_ELK_DATA_NOTE="false"
        fi

        if [[ $CHOICE == *"Search"* ]]; then
                export IS_ELK_SEARCH_NOTE="true"
        else
                export IS_ELK_SEARCH_NOTE="false"
        fi
        if [[ $CHOICE == *"Master"* ]]; then
                export IS_ELK_MASTER_NOTE="true"
        else
                export IS_ELK_MASTER_NOTE="false"
        fi
        export ENABLE_XPACK="true"
        #if [[ $CHOICE == *"X-Pack"* ]]; then
        #        export ENABLE_XPACK="true"
        #else
        #        export ENABLE_XPACK="false"
        #fi
        if $IS_DATASTORE; then
            PANE=5
        else
            PANE=6
        fi
    else
        if $IS_SENSOR; then
            PANE=3
        else
            PANE=2
        fi
    fi
}

function configureelk2 () {
    TEXT="Set the amount of RAM for each Elastic Node. Do not use more than 31(gigabytes). Only input whole numbers (ex. 2,3,10,17,31). Minimum 2(gigabytes).

    Input the number of data nodes to create."

    ES_RAM="2"
    ES_DATA_NODES="2"
    OPTIONS=()
    OPTIONS+=("ES Heap Memory:" 1 1	"$ES_RAM" 	1 30 10 0)
    if $IS_ELK_DATA_NOTE; then
        OPTIONS+=("Number of Data Nodes:" 2 1	"$ES_DATA_NODES" 	2 30 10 0)
    fi
    CHOICE=`dialog --title "Elastic Configuration" --backtitle "$BACKTITLE" --stdout --ok-label Next --cancel-label Back --form "$TEXT" 40 80 3 \
            "${OPTIONS[@]}"`
    RESPONSE=$?
    if [[ $RESPONSE -eq 0 ]]; then
        export ES_RAM=$(echo $CHOICE | cut -d' ' -f1)"g"
        if $IS_ELK_DATA_NOTE; then
            export ES_DATA_NODES=$(echo $CHOICE | cut -d' ' -f2)
        fi
        PANE=6
    else
        PANE=4
    fi
}

function pickmanagementinterface () {
    TEXT="Select the network management interface:"

    INTERFACES=$(nmcli c show | tail -$(($(nmcli c show | wc -l) - 1)) | cut -f1 -d' ')
    options=()
    for i in $INTERFACES
    do
    	options+=("$i" "")
    done

    CHOICE=`dialog --title "Management Interface" --backtitle "$BACKTITLE" --stdout --ok-label Next --cancel-label Back  --menu "$TEXT" 40 80 3 \
        "${options[@]}"`
    RESPONSE=$?
    if [[ $RESPONSE -eq 0 ]]; then
        export ANALYST_INTERFACE=$CHOICE
        if $IS_SENSOR; then
            PANE=7
        else
            PANE=8
        fi
    else
        if $IS_DATASTORE && $ENABLE_ELK; then
            PANE=5
        else
            if $IS_SENSOR; then
                if $ENABLE_ELK; then
                    PANE=4
                else
                    PANE=3
                fi
            else
                PANE=2
            fi
        fi
    fi
}

function pickcollectioninterface () {
    TEXT="Select the network capture interface:"
    INTERFACES=$(nmcli c show | tail -$(($(nmcli c show | wc -l) - 1)) | cut -f1 -d' ')
    options=()
    for i in $INTERFACES
    do
    	options+=("$i" "")
    done

    CHOICE=`dialog --title "Capture Interface" --backtitle "$BACKTITLE" --stdout --ok-label Next --cancel-label Back  --menu "$TEXT" 40 80 3 \
        "${options[@]}"`
    RESPONSE=$?
    if [[ $RESPONSE -eq 0 ]]; then
        export COLLECTION_INTERFACE=$CHOICE
        PANE=8
    else
        PANE=6
    fi
}

function configuredomain () {
    TEXT="Choose your domain and IP range.

    The IP range must only be the first 3 octets. If you want 192.168.1.0/24, input '192.168.1' This should not need to be changed if you picked the right management interface."
    if (($(hostname | grep -o "\." | wc -l) > 1)); then DOMAIN=$(echo `hostname` | sed 's/^[^\.]*\.//g'); else DOMAIN=""; fi
    export IP=$(ip addr | grep -e 'inet ' | grep -e ".*$ANALYST_INTERFACE$" | awk \
        '{print $2}' | cut -f1 -d '/' | awk -F . '{print $1"."$2"."$3}')

    CHOICE=`dialog --title "Domain Info" --backtitle "$BACKTITLE" --stdout --ok-label Next --cancel-label Back --form "$TEXT" 40 80 3 \
            "Domain:" 1 1	"$DOMAIN" 	1 30 30 0 \
            "IP Range:                                                  .0/24" 2 1	"$IP" 	2 30 30 0 `
    RESPONSE=$?
    if [[ $RESPONSE -eq 0 ]]; then
        export DOMAIN=$(echo $CHOICE | cut -d' ' -f1)
        export IP=$(echo $CHOICE | cut -d' ' -f2)
        PANE=9
    else
        if $IS_SENSOR; then
            PANE=7
        else
            PANE=6
        fi
    fi
}

function configureappips () {
    TEXT="Configure the IP address for each of the applications you are installing. Changing the first 3 octets is not recommended."
    export SENSOR_IP=$IP".10"
    export DATA_IP=$IP".11"
    export APP_IP=$IP".12"
    export IPA_IP=$IP".13"                       # FreeIPA IP
    export ES_IP=$IP".14"                        # ES Master Node IP
    export ESSEARCH_IP=$IP".15"                  # ES Search Head - Attached to Kibana
    export KIBANA_IP=$IP".16"                   # Kibana IP - attached to ES Search Head
    export OWNCLOUD_IP=$IP".17"                 # OwnCloud IP
    export GOGS_IP=$IP".18"                     # Gogs IP
    export CHAT_IP=$IP".19"                     # RocketChat IP
    export SPLUNK_IP=$IP".20"                   # Splunk IP
    export HIVE_IP=$IP".21"                     # TheHive IP
    export CORTEX_IP=$IP".22"                   # Cortex IP
    export ESDATA_IP=$IP".23"
    OPTIONS=()
    OPTIONS+=("Sensor:" 1 1	"$SENSOR_IP" 	1 30 30 0)
    OPTIONS+=("Datastore:" 2 1	"$DATA_IP" 	2 30 30 0)
    OPTIONS+=("Communication:" 3 1	"$APP_IP" 	3 30 30 0)
    OPTIONS+=("FreeIPA:" 4 1	"$IPA_IP" 	4 30 30 0)
    COUNT=5
    if $ENABLE_ELK; then
        OPTIONS+=("ElasticSearch Master:" $COUNT 1	"$ES_IP" 	$COUNT 30 30 0)
        let COUNT=$COUNT+1
    fi
    if $ENABLE_ELK && $IS_ELK_SEARCH_NOTE; then
        OPTIONS+=("ElasticSearch Search Node:" $COUNT 1	"$ESSEARCH_IP" 	$COUNT 30 30 0)
        let COUNT=$COUNT+1
        OPTIONS+=("Kibana:" $COUNT 1	"$KIBANA_IP" 	$COUNT 30 30 0)
        let COUNT=$COUNT+1
    fi
    if $ENABLE_SPLUNK; then
        OPTIONS+=("Splunk Enterprise:" $COUNT 1	"$SPLUNK_IP" 	$COUNT 30 30 0)
        let COUNT=$COUNT+1
    fi
    if $ENABLE_GOGS; then
        OPTIONS+=("GoGS:" $COUNT 1	"$GOGS_IP" 	$COUNT 30 30 0)
        let COUNT=$COUNT+1
    fi
    if $ENABLE_OWNCLOUD; then
        OPTIONS+=("OwnCloud:" $COUNT 1	"$OWNCLOUD_IP" 	$COUNT 30 30 0)
        let COUNT=$COUNT+1
    fi
    if $ENABLE_CHAT; then
        OPTIONS+=("RocketChat:" $COUNT 1	"$CHAT_IP" 	$COUNT 30 30 0)
        let COUNT=$COUNT+1
    fi
    if $ENABLE_HIVE; then
        OPTIONS+=("TheHive:" $COUNT 1	"$HIVE_IP" 	$COUNT 30 30 0)
        let COUNT=$COUNT+1
        OPTIONS+=("Cortex:" $COUNT 1	"$CORTEX_IP" 	$COUNT 30 30 0)
        let COUNT=$COUNT+1
    fi
    if $ENABLE_ELK && $IS_ELK_DATA_NOTE; then
            OPTIONS+=("1ST ElasticSearch Data Node:" $COUNT 1	"$ESDATA_IP" 	$COUNT 30 30 0)
    fi
    CHOICE=`dialog --title "IP Configuration" --backtitle "$BACKTITLE" --stdout --ok-label Next --cancel-label Back --form "$TEXT" 40 80 20 \
            "${OPTIONS[@]}"`
    RESPONSE=$?
    if [[ $RESPONSE -eq 0 ]]; then
        export SENSOR_IP=$(echo $CHOICE | cut -d' ' -f1)
        export DATA_IP=$(echo $CHOICE | cut -d' ' -f2)
        export APP_IP=$(echo $CHOICE | cut -d' ' -f3)
        export IPA_IP=$(echo $CHOICE | cut -d' ' -f4)
        COUNT=5
        if $ENABLE_ELK; then
            export ES_IP=$(echo $CHOICE | cut -d' ' -f$COUNT)
            let COUNT=$COUNT+1
        fi
        if $ENABLE_ELK && $IS_ELK_SEARCH_NOTE; then
            export ESSEARCH_IP=$(echo $CHOICE | cut -d' ' -f$COUNT)
            let COUNT=$COUNT+1
            export KIBANA_IP=$(echo $CHOICE | cut -d' ' -f$COUNT)
            let COUNT=$COUNT+1
        fi
        if $ENABLE_SPLUNK; then
            export SPLUNK_IP=$(echo $CHOICE | cut -d' ' -f$COUNT)
            let COUNT=$COUNT+1
        fi
        if $ENABLE_GOGS; then
            export GOGS_IP=$(echo $CHOICE | cut -d' ' -f$COUNT)
            let COUNT=$COUNT+1
        fi
        if $ENABLE_OWNCLOUD; then
            export OWNCLOUD_IP=$(echo $CHOICE | cut -d' ' -f$COUNT)
            let COUNT=$COUNT+1
        fi
        if $ENABLE_CHAT; then
            export CHAT_IP=$(echo $CHOICE | cut -d' ' -f$COUNT)
            let COUNT=$COUNT+1
        fi
        if $ENABLE_HIVE; then
            export HIVE_IP=$(echo $CHOICE | cut -d' ' -f$COUNT)
            let COUNT=$COUNT+1
            export CORTEX_IP=$(echo $CHOICE | cut -d' ' -f$COUNT)
            let COUNT=$COUNT+1
        fi
        if $ENABLE_ELK && $IS_ELK_DATA_NOTE; then
                export ESDATA_IP=$(echo $CHOICE | cut -d' ' -f$COUNT)
        fi
        PANE=10
    else
        PANE=8
    fi
}

function configureuser () {
    TEXT="Create the first user. This user will be an administrator. The password must be at least 8 characters long. Do not put spaces in your password."
    OPTIONS=()
    OPTIONS+=("Username:" 1 1	"$IPA_USERNAME" 	1 30 40 0 0)
    OPTIONS+=("Password:" 2 1	"" 	2 30 40 0 1)
    OPTIONS+=("Verify Password:" 3 1	"" 	3 30 40 0 1)
    CHOICE=`dialog --insecure --title "Administrator Configuration" --backtitle "$BACKTITLE" --stdout --ok-label Next --cancel-label Back --mixedform "$TEXT" 40 80 3 \
            "${OPTIONS[@]}"`
    RESPONSE=$?
    P1=$(echo $CHOICE | cut -d' ' -f2)
    P2=$(echo $CHOICE | cut -d' ' -f3)
    if [[ $RESPONSE -eq 0 ]]; then
        if [ ${#P1} -ge 8 ] && [ $P1 == $P2 ]; then
            export IPA_USERNAME=$(echo $CHOICE | cut -d' ' -f1)
            export IPA_ADMIN_PASSWORD=$P1
            PANE=11
        else
            if [[ ${#P1} -lt 8 ]]; then
                dialog --backtitle "$BACKTITLE" \
                --title "Error" \
                --msgbox 'Password is less than 8 characters.' 10 30
                PANE=10
            fi
            if [[ $P1 != $P2 ]]; then
                dialog --backtitle "$BACKTITLE" \
                --title "Error" \
                --msgbox 'Passwords do not match.' 10 30
                PANE=10
            fi
        fi
    else
        PANE=9
    fi
}

function startinstall () {
    TEXT="You have selected the following configuration:\n"
    TEXT+="\n"
    if $IS_SENSOR; then
        TEXT+=" * Sensor: $SENSOR_IP\n"
        TEXT+="    - Capture Interface: $COLLECTION_INTERFACE\n"
        if $ENABLE_BRO; then
            TEXT+="    - Bro/Zeek: $BRO_WORKERS workers\n"
        fi
        if $ENABLE_SURICATA; then
            TEXT+="    - Suricata\n"
        fi
        if $ENABLE_STENOGRAPHER; then
            TEXT+="    - Stenographer: $STENO_THREADS threads\n"
        fi
        if $ENABLE_ELK; then
            TEXT+="    - FileBeat\n"
        fi
        if $ENABLE_SPLUNK; then
            TEXT+="    - Splunk Forwarder\n"
        fi
        TEXT+="\n"
    fi
    if $IS_DATASTORE; then
        TEXT+=" * DataStore: $DATA_IP\n"
        if $ENABLE_ELK && $IS_ELK_MASTER_NOTE; then
            TEXT+="    - ElasticSearch Master($ES_RAM): $ES_IP\n"
        fi
        if $ENABLE_ELK && $IS_ELK_DATA_NOTE; then
            TEXT+="    - $ES_DATA_NODES x ElasticSearch Data($ES_RAM) starting at $ESDATA_IP\n"
        fi
        if $ENABLE_ELK && $IS_ELK_SEARCH_NOTE; then
            TEXT+="    - ElasticSearch Search($ES_RAM): $ESSEARCH_IP\n"
            TEXT+="    - Kibana: $KIBANA_IP\n"
        fi
        if $ENABLE_ELK && $ENABLE_XPACK; then
            TEXT+="    - X-Pack\n"
        fi
        if $ENABLE_SPLUNK; then
            TEXT+="    - Splunk Enterprise: $SPLUNK_IP\n"
        fi
        TEXT+="\n"
    fi
    if $IS_APP_SERVER; then
        TEXT+=" * Communication: $APP_IP\n"
        if $ENABLE_OWNCLOUD; then
            TEXT+="    - OwnCloud: $OWNCLOUD_IP\n"
        fi
        if $ENABLE_GOGS; then
            TEXT+="    - GoGS: $GOGS_IP\n"
        fi
        if $ENABLE_CHAT; then
            TEXT+="    - RocketChat: $CHAT_IP\n"
        fi
        if $ENABLE_HIVE && $IS_APP_SERVER; then
            TEXT+="    - TheHive: $HIVE_IP\n"
            TEXT+="    - Cortex: $CORTEX_IP\n"
        fi
        TEXT+="\n"
    fi
    TEXT+=" * Management Interface: $ANALYST_INTERFACE\n"
    TEXT+=" * FreeIPA Server: $IPA_IP\n"
    TEXT+="    -  Domain: $DOMAIN\n"
    TEXT+="    -  Username: $IPA_USERNAME\n"
    TEXT+="\n"
    TEXT+="Would you like to install?"
    dialog --title "Install Confirmation" --backtitle "$BACKTITLE" --stdout --extra-button --ok-label Install --extra-label Quit --cancel-label Back --yesno "${TEXT}" 40 80
    RESPONSE=$?
    if [[ $RESPONSE -eq 0 ]]; then
        PANE=12
    else
        if [[ $RESPONSE -eq 1 ]]; then
            PANE=10
        else
            PANE=0
        fi
    fi
}


function configuresensor () {
    CPU=`echo "$(( $(lscpu -p=CPU | tail -1) + 1 ))"`
    TEXT="Bro and Google Stenographer work best when configured with the correct number of cores for their workers and threads.

    Bro should have 4 workers per 1 Gbps of traffic you want to collect. Thus, 5Gbps requires 20 workers.

    Stenographer should have 1 thread per 1Gbps of traffic you want to collect, however you should use at least 2 threads. 5Gbps means 5 threads.

    You cannot exceed the total number of cores your system has. You have $CPU CPU cores."
    BRO_WORKERS=4
    STENO_THREADS=2
    OPTIONS=()
    if $ENABLE_BRO; then
        OPTIONS+=("Bro Workers:" 1 1	"$BRO_WORKERS" 	1 30 10 0)
        if $ENABLE_STENOGRAPHER; then
            OPTIONS+=("Stenographer threads:" 2 1	"$STENO_THREADS" 	2 30 10 0)
        else
            export STENO_THREADS=""
        fi
    else
        export BRO_WORKERS=""
        if $ENABLE_STENOGRAPHER; then
            OPTIONS+=("Stenographer threads:" 1 1	"$STENO_THREADS" 	1 30 10 0)
        fi
    fi
    CHOICE=`dialog --title "Sensor Configuration" --backtitle "$BACKTITLE" --stdout --ok-label Next --cancel-label Back --form "$TEXT" 40 80 3 \
            "${OPTIONS[@]}"`
    RESPONSE=$?
    if [[ $RESPONSE -eq 0 ]]; then
        if $ENABLE_BRO; then
            export BRO_WORKERS=$(echo $CHOICE | cut -d' ' -f1)
            export STENO_THREADS=$(echo $CHOICE | cut -d' ' -f2)
        else
            export BRO_WORKERS=""
            export STENO_THREADS=$(echo $CHOICE | cut -d' ' -f1)
        fi
        if $ENABLE_ELK; then
            PANE=4
        else
            PANE=6
        fi
    else
        PANE=2
    fi
}

function appchooser () {
    TEXT="Select the applications you wish to install and configure:

    * Bro/Zeek - A network security monitoring tool that generates metadata logs from collected traffic.

    * Suricata - A rule based IDS to alert on malicious traffic.

    * Stenographer - captures and indexes full pcap to disk.

    * Elastic Stack - For sensors, this installs filebeat to ship logs to a datastore. For a datastore, this installs Logstash, ElasticSearch, and Kibana.

    * Splunk - For sensors, this installs the Splunk Forwarder to ship logs to a datastore. For a datastore, this installs Splunk Enterprise.

    * GoGS - GoGS is an information repository with version control.

    * RocketChat - RocketChat is a web-based chat system.

    * TheHive with Cortex - TheHive is a Cyber Incident Tracking Ticket system and Cortex provides a threat intelligence platform.

    * OwnCloud - Owncloud is a document hosting service."
    OPTIONS=()
    if $IS_SENSOR; then
        OPTIONS+=("Bro/Zeek" "" $(if $ENABLE_BRO; then echo on; else echo off; fi))
        OPTIONS+=("Suricata" "" $(if $ENABLE_SURICATA; then echo on; else echo off; fi))
        OPTIONS+=("Stenographer" "" $(if $ENABLE_STENOGRAPHER; then echo on; else echo off; fi))
    else
        export ENABLE_BRO="false"
        export ENABLE_SURICATA="false"
        export ENABLE_STENOGRAPHER="false"
    fi
    if $IS_SENSOR || $IS_DATASTORE; then
        OPTIONS+=("Elastic Stack" "" $(if $ENABLE_ELK; then echo on; else echo off; fi))
        OPTIONS+=("Splunk" "" $(if $ENABLE_SPLUNK; then echo on; else echo off; fi))
    else
        export ENABLE_ELK="false"
        export ENABLE_SPLUNK="false"
    fi
    if $IS_APP_SERVER; then
        OPTIONS+=("GoGS" "" $(if $ENABLE_GOGS; then echo on; else echo off; fi))
        OPTIONS+=("RocketChat" "" $(if $ENABLE_CHAT; then echo on; else echo off; fi))
        OPTIONS+=("TheHive + Cortex" "" $(if $ENABLE_HIVE; then echo on; else echo off; fi))
        OPTIONS+=("OwnCloud" "" $(if $ENABLE_OWNCLOUD; then echo on; else echo off; fi))
    else
        export ENABLE_GOGS="false"
        export ENABLE_CHAT="false"
        export ENABLE_HIVE="false"
        export ENABLE_OWNCLOUD="false"
    fi
    CHOICE=`dialog --title "Application Selection" --backtitle "$BACKTITLE" --stdout --ok-label Next --cancel-label Back --checklist "$TEXT" 40 80 9 \
            "${OPTIONS[@]}"`

    RESPONSE=$?
    if [[ $RESPONSE -eq 0 ]]; then
        if [[ $CHOICE == *"Bro"* ]]; then
                export ENABLE_BRO="true"
        else
                export ENABLE_BRO="false"
        fi
        if [[ $CHOICE == *"Suricata"* ]]; then
                export ENABLE_SURICATA="true"
        else
                export ENABLE_SURICATA="false"
        fi
        if [[ $CHOICE == *"Stenographer"* ]]; then
                export ENABLE_STENOGRAPHER="true"
        else
                export ENABLE_STENOGRAPHER="false"
        fi
        if [[ $CHOICE == *"Elastic"* ]]; then
                export ENABLE_ELK="true"
        else
                export ENABLE_ELK="false"
        fi
        if [[ $CHOICE == *"Splunk"* ]]; then
                export ENABLE_SPLUNK="true"
        else
                export ENABLE_SPLUNK="false"
        fi
        if [[ $CHOICE == *"GoGS"* ]]; then
                export ENABLE_GOGS="true"
        else
                export ENABLE_GOGS="false"
        fi
        if [[ $CHOICE == *"RocketChat"* ]]; then
                export ENABLE_CHAT="true"
        else
                export ENABLE_CHAT="false"
        fi
        if [[ $CHOICE == *"Hive"* ]]; then
                export ENABLE_HIVE="true"
        else
                export ENABLE_HIVE="false"
        fi
        if [[ $CHOICE == *"OwnCloud"* ]]; then
                export ENABLE_OWNCLOUD="true"
        else
                export ENABLE_OWNCLOUD="false"
        fi

        if $IS_SENSOR && ( $ENABLE_BRO || $ENABLE_STENOGRAPHER ); then
            PANE=3
        else
            if $IS_DATASTORE && $ENABLE_ELK; then
                PANE=4
            else
                PANE=6
            fi
        fi
    else
        PANE=1
    fi
}

while [[ $PANE -gt 0 && $PANE -lt 12  ]]; do
    if [[ $PANE -eq 1 ]]; then
        serverroles
    fi

    if [[ $PANE -eq 2 ]]; then
        appchooser
    fi

    if [[ $PANE -eq 3 ]]; then
        configuresensor
    fi

    if [[ $PANE -eq 4 ]]; then
        configureelk
    fi

    if [[ $PANE -eq 5 ]]; then
        configureelk2
    fi

    if [[ $PANE -eq 6 ]]; then
        pickmanagementinterface
    fi

    if [[ $PANE -eq 7 ]]; then
        pickcollectioninterface
    fi

    if [[ $PANE -eq 8 ]]; then
        configuredomain
    fi

    if [[ $PANE -eq 9 ]]; then
        configureappips
    fi

    if [[ $PANE -eq 10 ]]; then
        configureuser
    fi

    if [[ $PANE -eq 11 ]]; then
        startinstall
    fi
done

if [[ $PANE -eq 0 ]]; then
    exit 0
fi
