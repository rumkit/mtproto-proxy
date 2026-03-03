#!/bin/sh

# set variables
[ -z "$CONFIG_PATH" ] && CONFIG_PATH="/data"
[ -z "$CLIENT_PORT" ] && CLIENT_PORT=443
[ -z "$EXT_PORT"] && EXT_PORT=14443
USER_SECRETS_FILE="${CONFIG_PATH}/user-secrets.txt"
EXT_IP=$(curl ifconfig.co/ip -s)
INT_IP=$(hostname -I | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
USER_SECRETS_COUNT=5

# Download TG key and proxy configuration if they don't exist
if [ ! -f "${CONFIG_PATH}/proxy-secret" ]; then
curl -s https://core.telegram.org/getProxySecret -o ${CONFIG_PATH}/proxy-secret
fi
if [ ! -f " ${CONFIG_PATH}/proxy-multi.conf" ]; then
curl -s https://core.telegram.org/getProxyConfig -o ${CONFIG_PATH}/proxy-multi.conf
fi


# Check if user secrets need to be generated
if [ ! -f "$USER_SECRETS_FILE" ]; then
    echo "User secrets file not found. Creating new file and generating secrets..."
    for i in $(seq 1 $USER_SECRETS_COUNT); do
        head -c 16 /dev/urandom | xxd -ps >> "$USER_SECRETS_FILE"
    done
    echo "Done."
fi

# Parse the user secrets file
echo "
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
USE THESE LINKS WISELY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n"

USER_SECRETS=""
while IFS= read -r key; do
    # skip empty lines
    [ -z "$key" ] && continue 
    USER_SECRETS="$USER_SECRETS -S $key"
    echo "https://t.me/proxy?server=$EXT_IP&port=$EXT_PORT&secret=$key"
done < "$USER_SECRETS_FILE"
echo "
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n"

# Run cron for automatic config updates
cron

# Run proxy
exec ./mtproto-proxy -u nobody -p 8888 -H 443 \
     --aes-pwd ${CONFIG_PATH}/proxy-secret ${CONFIG_PATH}/proxy-multi.conf \
     --http-stats \
     --nat-info ${INT_IP}:${EXT_IP}
     -M 1
     ${USER_SECRETS}
