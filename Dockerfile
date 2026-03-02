FROM ubuntu:latest AS build
ARG MTPROTO_REPO_URL="https://github.com/TelegramMessenger/MTProxy"

# install build deps
RUN apt -y update; \
    apt -y install git curl build-essential libssl-dev zlib1g-dev xxd;
WORKDIR /mtproto/

# download proxy src
RUN git clone ${MTPROTO_REPO_URL} src
WORKDIR /mtproto/src/

# build
RUN make
WORKDIR /mtproto/src/objs/bin

# download key and config
RUN curl -s https://core.telegram.org/getProxySecret -o proxy-secret \
    curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf



