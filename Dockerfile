FROM quay.io/aptible/alpine:3.6

ENV CACHE 1
ENV FILEBEAT_VERSION 7.4.2
ENV SHA 19b002520d86415d85a9753787227dd223f1ea556aa877d76448d11de87e0cdeb4e270d429ea26960a1578cc89efc66d448058297e81051ef83e8a6543ebf3a2
ENV FILEBEAT_HOME "/filebeat-${FILEBEAT_VERSION}-linux-x86_64"
ENV PATH ${FILEBEAT_HOME}:$PATH

# libc6-compat is required by filebeat:
# https://discuss.elastic.co/t/filebeat-6-x-could-not-support-running-under-os-alpine/116195
RUN apk update && \
    apk-install curl ruby libc6-compat ruby-json


RUN curl -O "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${FILEBEAT_VERSION}-linux-x86_64.tar.gz" && \
    echo "${SHA}  filebeat-${FILEBEAT_VERSION}-linux-x86_64.tar.gz" | sha512sum -c - && \
    tar zxf "filebeat-${FILEBEAT_VERSION}-linux-x86_64.tar.gz" && \
    rm "filebeat-${FILEBEAT_VERSION}-linux-x86_64.tar.gz"

WORKDIR ${FILEBEAT_HOME}

COPY templates/filebeat.yml.erb filebeat.yml.erb
COPY bin/run-joe-cool.sh run-joe-cool.sh

# Run tests.
 RUN apk-install openssl redis
 ADD test /tmp/test
 RUN bats /tmp/test
 RUN apk del openssl redis

# Any docker logs need to be mounted at /tmp/dockerlogs. Typically, this means that
# a volume should be created mapping /var/lib/docker/containers to /tmp/dockerlogs
# in the container.
VOLUME ["/tmp/dockerlogs"]

CMD ["/bin/bash", "run-joe-cool.sh"]
