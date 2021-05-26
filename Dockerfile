FROM node:16-alpine

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

# Install dependencies
RUN apk add --update --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing \
        openjdk16 \
        mediainfo \
        chromaprint \
        p7zip \
        unrar

# Install Filebot
ENV FILEBOT_VERSION 4.9.3
ENV FILEBOT_URL https://get.filebot.net/filebot/FileBot_$FILEBOT_VERSION/FileBot_$FILEBOT_VERSION-portable.tar.xz
ENV FILEBOT_SHA256 4fecbc93be7bfea14254e09cfd235cedaf8a9b2b1c3e5a30b9b35063332bf236
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