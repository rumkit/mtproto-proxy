FROM ubuntu:latest AS build
ARG MTPROTO_REPO_URL="https://github.com/TelegramMessenger/MTProxy"

# install build deps
RUN apt -y update; \
    apt -y install git curl build-essential libssl-dev zlib1g-dev xxd;
WORKDIR /

# download proxy src
RUN git clone ${MTPROTO_REPO_URL} mtproto
WORKDIR /mtproto

# build
RUN make
WORKDIR /mtproto/objs/bin

# download key and config
RUN curl -s https://core.telegram.org/getProxySecret -o proxy-secret; \
    curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf

FROM ubuntu:latest

# install runtime deps
RUN apt -y update; \
    apt -y install wget cron xxd; \
    apt -y clean

# copy artifacts from build stage
COPY --from=build /mtproto/objs/bin /mtproxy
COPY start.sh /mtproxy
WORKDIR /mtproxy

# setup cron to periodically fetch tg configuration as it may change
RUN (crontab -l 2>/dev/null; echo "0 3 * * * curl -s https://core.telegram.org/getProxySecret -o /srv/MTProxy/objs/bin/proxy-secret >> /var/log/cron.log 2>&1") | crontab - ;\
    (crontab -l 2>/dev/null; echo "0 3 * * * curl -s https://core.telegram.org/getProxyConfig -o /srv/MTProxy/objs/bin/proxy-multi.conf >> /var/log/cron.log 2>&1") | crontab - ;\
# fetch stats from a local endpoint
    (crontab -l 2>/dev/null; echo '0 3 * * * wget --output-document="/mtproxy/stats/$(date +%d.%m.%y).log" localhost:8888/stats  >> /var/log/cron.log 2>&1') | crontab - ;\
# restart proxy to allow update configuration if necessary
    (crontab -l 2>/dev/null; echo '0 4 * * *  pkill -f mtproto-proxy  >> /var/log/cron.log 2>&1') | crontab - ;

EXPOSE 8888 443
# starting mtproto-proxy
ENTRYPOINT ["./start.sh"]