PANE=1
BACKTITLE="CozyStack Pre-Install"
export LOCAL_REPO="false"

dialog --backtitle "$BACKTITLE" \
--title "About" \
--msgbox 'This is will download packages to install CozyStack. Enjoy.' 10 30

function selectos () {
    TEXT="Are you using Redhat Enterprise Linux or CentOS?"
    options=()
    options+=("RedHat Enterprise Linux" "")
    options+=("CentOS Linux" "")

    CHOICE=`dialog --title "Choose OS" --backtitle "$BACKTITLE" --stdout --ok-label Next --cancel-label Quit  --menu "$TEXT" 40 80 3 \
        "${options[@]}"`
    RESPONSE=$?
    if [[ $RESPONSE -eq 0 ]]; then
        if [[ $CHOICE == *"RedHat"* ]]; then
            export IS_RHEL="true"
        else
            export IS_RHEL="false"
        fi
        PANE=2
    else
        PANE=0
    fi
}

function configuredomain () {
    TEXT="Choose a Domain name and Admimistrator Password. This password will be required during install. The password must contain at least 8 characters and no spaces."
    OPTIONS=()
    if (($(hostname | grep -o "\." | wc -l) > 1)); then DOMAIN=$(echo `hostname` | sed 's/^[^\.]*\.//g'); else DOMAIN=""; fi
    if [ DOMAIN == "" ]; then
        OPTIONS+=("Domain:" 1 1	"example.com" 	1 30 40 0 0)
    else
        OPTIONS+=("Domain:" 1 1	"$DOMAIN" 	1 30 40 0 0)
    fi
    OPTIONS+=("Password:" 2 1	"" 	2 30 40 0 1)
    OPTIONS+=("Verify Password:" 3 1	"" 	3 30 40 0 1)
    CHOICE=`dialog --insecure --title "Administrator Configuration" --backtitle "$BACKTITLE" --stdout --ok-label Next --cancel-label Back --mixedform "$TEXT" 40 80 3 \
            "${OPTIONS[@]}"`
    RESPONSE=$?
    P1=$(echo $CHOICE | cut -d' ' -f2)
    P2=$(echo $CHOICE | cut -d' ' -f3)
    if [[ $RESPONSE -eq 0 ]]; then
        if [ ${#P1} -ge 8 ] && [ $P1 == $P2 ]; then
            export DOMAIN=$(echo $CHOICE | cut -d' ' -f1)
            export PASSWORD=$P1
            PANE=3
        else
            if [[ ${#P1} -lt 8 ]]; then
                dialog --backtitle "$BACKTITLE" \
                --title "Error" \
                --msgbox 'Password is less than 8 characters.' 10 30
                PANE=2
            fi
            if [[ $P1 != $P2 ]]; then
                dialog --backtitle "$BACKTITLE" \
                --title "Error" \
                --msgbox 'Passwords do not match.' 10 30
                PANE=2
            fi
        fi
    else
        PANE=1
    fi
}

function startdownload () {
    dialog --title "Download Confirmation" --backtitle "$BACKTITLE" --stdout --extra-button --ok-label Download --extra-label Quit --cancel-label Back --yesno "Would you like to start the download?" 40 80
    RESPONSE=$?
    if [[ $RESPONSE -eq 0 ]]; then
        PANE=4
    else
        if [[ $RESPONSE -eq 1 ]]; then
            PANE=2
        else
            PANE=0
        fi
    fi
}

while [[ $PANE -gt 0 && $PANE -lt 4  ]]; do
    # RHEL OR CENTOS
    if [[ $PANE -eq 1 ]]; then
        selectos
    fi

    # Domain + Password
    if [[ $PANE -eq 2 ]]; then
        configuredomain
    fi

    # Download
    if [[ $PANE -eq 3 ]]; then
        startdownload
    fi
done

if [[ $PANE -eq 0 ]]; then
    exit 0
fi
