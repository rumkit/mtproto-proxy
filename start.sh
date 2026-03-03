#!/bin/sh

USER_SECRETS_FILE="${CONFIG_PATH}/user-secrets.txt"

# Check if user secrets need to be generated
if [ ! -f "$USER_SECRETS_FILE" ]; then
    echo "User secrets file not found. Creating new file and generating secrets..."
    for i in $(seq 1 10); do
        head -c 16 /dev/urandom | xxd -ps >> "$USER_SECRETS_FILE"
    done
    echo "Done."
    echo "
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
NEW SECRETS GENERATED. USE THEM WISELY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
"
    cat $USER_SECRETS_FILE
    echo "
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
"
fi

# Parse the user secrets file
USER_SECRETS=""
while IFS= read -r key; do
    # skip empty lines
    [ -z "$key" ] && continue 
    USER_SECRETS="$USER_SECRETS -S $key"
done < "$USER_SECRETS_FILE"

exec ./mtproto-proxy -u nobody -p 8888 -H 443 \
     --aes-pwd ${CONFIG_PATH}/proxy-secret ${CONFIG_PATH}/proxy-multi.conf \
     --http-stats \
     $USER_SECRETS
