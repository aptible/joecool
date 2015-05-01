#!/bin/bash
: ${LOGSTASH_ENDPOINT:?"Error: environment variable LOGSTASH_ENDPOINT should contain the Gentleman Jerry endpoint."}
: ${LOGSTASH_CERTIFICATE:?"Error: environment variable LOGSTASH_CERTIFICATE should contain Gentleman Jerry's certificate."}
: ${CONTAINERS_TO_MONITOR:?"Error: environment variable CONTAINERS_TO_MONITOR should contain a comma-separated list of container ids."}
export TAIL_OPT=$([ -z "$READ_FROM_BEGINNING"] && echo "-tail=true")

if [ ! -d /tmp/dockerlogs ]; then
  echo "/tmp/dockerlogs should exist and contain Docker logs."
  exit 1
fi
erb logstash-forwarder.config.erb > logstash-forwarder/logstash-forwarder.config && \
cd logstash-forwarder && \
echo "$LOGSTASH_CERTIFICATE" > logstash.crt && \
./logstash-forwarder -config logstash-forwarder.config -max-line-bytes=101376 $TAIL_OPT
