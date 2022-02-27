ARG ALPINE_VERSION=3.15

FROM alpine:$ALPINE_VERSION AS build

RUN apk add --update --no-cache \
    alpine-sdk \
    git

RUN abuild-keygen -a -n \
    && cp -v /root/.abuild/*.rsa.pub /etc/apk/keys \
    && mkdir aports \
    && cd aports \
    && git init \
    && git remote --verbose add origin git://git.alpinelinux.org/aports \
    && git config core.sparsecheckout true \
    && git sparse-checkout init \
    && git sparse-checkout set non-free/unrar \
    && git pull --verbose origin 3.15-stable \
    && cd non-free/unrar \
    && abuild -F checksum \
    && abuild -F -r -v

FROM node:16-alpine$ALPINE_VERSION

ARG PUID=1000
ARG PGID=1000
ARG PORT=8080
ARG FILEBOT_OUTPUT_DIR=/storage
ARG FILEBOT_LOGS_DIR=/logs

# Required by the app
ENV PORT=$PORT
ENV FILEBOT_OUTPUT_DIR=$FILEBOT_OUTPUT_DIR
ENV FILEBOT_LOGS_DIR=$FILEBOT_LOGS_DIR

# Setup base node image
RUN deluser --remove-home node && \
    addgroup -S node -g $PGID && \
    adduser -S -G node -u $PUID node

# Copy build key and apks built in build step
COPY --from=build /root/packages /packages/
COPY --from=build /root/.abuild/*.rsa.pub /etc/apk/keys/

# Install dependencies
RUN apk add --update --no-cache \
    --repository /packages/non-free \
        openjdk16-jre \
        mediainfo \
        chromaprint \
        p7zip \
        unrar

# Install Filebot
ENV FILEBOT_VERSION 4.9.5
ENV FILEBOT_URL https://get.filebot.net/filebot/FileBot_$FILEBOT_VERSION/FileBot_$FILEBOT_VERSION-portable.tar.xz
ENV FILEBOT_SHA256 2cdbdf02e78331dd9379d2ba6ea9cd1be27fe188616e651c6bd8b2524a143641
ENV FILEBOT_HOME /opt/filebot
RUN set -eux \
 ## * fetch portable package
 && wget -O /tmp/filebot.tar.xz "$FILEBOT_URL" \
 && echo "$FILEBOT_SHA256 */tmp/filebot.tar.xz" | sha256sum -c - \
 ## * install application files
 && mkdir -p "$FILEBOT_HOME" \
 && tar --extract --file /tmp/filebot.tar.xz --directory "$FILEBOT_HOME" --verbose \
 && rm -v /tmp/filebot.tar.xz \
 ## * delete incompatible native binaries
 && find /opt/filebot/lib -type f -not -name libjnidispatch.so -delete \
 ## * link /opt/filebot/data -> /data to persist application data files to the persistent data volume
 && ln -s /data /opt/filebot/data

# Configure Filebot
ENV HOME /data
ENV LANG C.UTF-8
ENV FILEBOT_OPTS "-Dapplication.deployment=docker -Dnet.filebot.archive.extractor=ShellExecutables -Duser.home=$HOME"

# Install server
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .

# Configure image
VOLUME /data /config /storage /downloads /logs
EXPOSE $PORT

# Start
USER node
CMD [ "node", "server.js" ]