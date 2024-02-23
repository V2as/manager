#!/bin/bash

set -e

EVENT="{{ event_name }}"
AWG_MANAGER="/etc/amnezia/amneziawg/awg-manager.sh"
SESSION_ID="{{ user.gen_session.id }}"
API_URL="{{ config.api.url }}"
CURL="curl"

echo "EVENT=$EVENT"

case $EVENT in
    INIT)
        SERVER_HOST="{{ server.settings.host_name }}"
        SERVER_INTERFACE="{{ server.settings.interface }}"
        if [[ -z "$SERVER_INTERFACE" ]]; then
            SERVER_INTERFACE=$(ip route | awk '/default/ {print $5; exit}')
        fi
        if [ -z $SERVER_HOST ]; then
            SERVER_HOST="{{ server.settings.host }}"
        fi
        
        echo "Install required packages"
        apt update >> /dev/nul
        apt install -y \
            iproute2 \
            iptables \
            curl \
            wget \
            git \
            build-essential \
            make
            
        echo "Check domain: $API_URL"
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $API_URL/shm/v1/test)
        if [ $HTTP_CODE -ne '200' ]; then
            echo "ERROR: incorrect API URL: $API_URL"
            echo "Got status: $HTTP_CODE"
            exit 1
        fi
        echo "Install Golang"
        if ! command -v go &> /dev/null; then
            echo "Install"
            mkdir -p /opt/go
            cd /opt/go
            wget -q https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
            rm -rf /usr/local/go && tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
            echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile
            source /etc/profile
            source $HOME/.bashrc
            if [[ "$SHELL" == "zsh" ]]; then
                source $HOME/.zshrc
            fi
        else
            echo "Golang installed"
        fi
        
        echo "Install Amnezia-Go"
        if test -d /opt/amnezia-go; then
            cd /opt/amnezia-go
            make >> /dev/null
            echo "installed"
        else
            echo "install"
            git clone https://github.com/amnezia-vpn/amneziawg-go.git /opt/amnezia-go >> /dev/null
            cd /opt/amnezia-go
            make >> /dev/null
            cp /opt/amnezia-go/amneziawg-go /usr/bin/amneziawg-go
        fi
        echo "Install Amnezia-tools"
        if test -d /opt/amnezia-tools; then
            cd /opt/amnezia-tools/src
            make >> /dev/null
            make install 
            echo "installed"
        else
            echo "install"
            git clone https://github.com/amnezia-vpn/amneziawg-tools.git /opt/amnezia-tools  >> /dev/null
            cd /opt/amnezia-tools/src
            make >> /dev/null
            make install 
        fi
        echo
        echo "Download awg-manager.sh"
        mkdir -p /etc/amnezia/amneziawg
        $CURL -s https://raw.githubusercontent.com/bkeenke/awg-manager/master/awg-manager.sh > $AWG_MANAGER

        echo "Init server"
        chmod 700 $AWG_MANAGER
        if [ $SERVER_INTERFACE ]; then
            $AWG_MANAGER -i -s $SERVER_HOST -I $SERVER_INTERFACE
        else
            $AWG_MANAGER -i -s $SERVER_HOST
        fi
        ;;
    CREATE)
        echo "Create new user"
        USER_CFG=$($AWG_MANAGER -u "{{ us.id }}" -c -p)

        echo "Upload user key to SHM"
        $CURL -s -XPUT \
            -H "session-id: $SESSION_ID" \
            -H "Content-Type: text/plain" \
            $API_URL/shm/v1/storage/manage/vpn{{ us.id }} \
            --data-binary "$USER_CFG"
        echo "done"
        ;;
    ACTIVATE)
        echo "Activate user"
        $AWG_MANAGER -u "{{ us.id }}" -U
        echo "done"
        ;;
    BLOCK)
        echo "Block user"
        $AWG_MANAGER -u "{{ us.id }}" -L
        echo "done"
        ;;
    REMOVE)
        echo "Remove user"
        $AWG_MANAGER -u "{{ us.id }}" -d

        echo "Remove user key from SHM"
        $CURL -s -XDELETE \
            -H "session-id: $SESSION_ID" \
            $API_URL/shm/v1/storage/manage/vpn{{ us.id }}
        echo "done"
        ;;
    *)
        echo "Unknown event: $EVENT. Exit."
        exit 0
        ;;
esac
