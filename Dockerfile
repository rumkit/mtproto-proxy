FROM ubuntu:latest AS build
ARG MTPROTO_REPO_URL="https://github.com/TelegramMessenger/MTProxy"

# install build deps
RUN apt -y update; \
    apt -y install git build-essential libssl-dev zlib1g-dev;
WORKDIR /

# download proxy src
RUN git clone ${MTPROTO_REPO_URL} mtproto
WORKDIR /mtproto

# build
RUN make

FROM ubuntu:latest

ENV CONFIG_PATH="/data"
# install runtime deps
RUN apt -y update; \
    apt -y install cron xxd curl; \
    apt -y clean

# copy artifacts from build stage
COPY --from=build /mtproto/objs/bin/ /mtproxy
COPY start.sh /mtproxy
RUN mkdir /data

WORKDIR /mtproxy

# download key and config
RUN curl -s https://core.telegram.org/getProxySecret -o ${CONFIG_PATH}/proxy-secret; \
    curl -s https://core.telegram.org/getProxyConfig -o ${CONFIG_PATH}/proxy-multi.conf

# setup cron to periodically fetch tg configuration as it may change
RUN (crontab -l 2>/dev/null; echo "0 3 * * * curl -s https://core.telegram.org/getProxySecret -o ${CONFIG_PATH}/proxy-secret >> /var/log/cron.log 2>&1") | crontab - ;\
    (crontab -l 2>/dev/null; echo "0 3 * * * curl -s https://core.telegram.org/getProxyConfig -o ${CONFIG_PATH}/proxy-multi.conf >> /var/log/cron.log 2>&1") | crontab - ;\
# fetch stats from a local endpoint
    (crontab -l 2>/dev/null; echo "0 3 * * * curl -s localhost:8888/stats -o /mtproxy/stats/$(date +%d.%m.%y).log >> /var/log/cron.log 2>&1") | crontab - ;\
# restart proxy to allow update configuration if necessary
    (crontab -l 2>/dev/null; echo "0 4 * * *  pkill -f mtproto-proxy  >> /var/log/cron.log 2>&1") | crontab - ;

# ports
EXPOSE 8888 443/tcp 443/udp
# healthcheck
HEALTHCHECK --interval=60s --timeout=30s --start-period=10s CMD curl -f http://localhost:8888/stats || exit 1
# starting mtproto-proxy
ENTRYPOINT ["./start.sh"]