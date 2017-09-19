#!/bin/bash
set -o errexit

: ${LOGSTASH_ENDPOINT:?"Error: environment variable LOGSTASH_ENDPOINT should contain the Gentleman Jerry endpoint."}
: ${LOGSTASH_CERTIFICATE:?"Error: environment variable LOGSTASH_CERTIFICATE should contain Gentleman Jerry's certificate."}

if [ ! -d /tmp/dockerlogs ]; then
  echo "/tmp/dockerlogs should exist and contain Docker logs."
  exit 1
fi

# We persist whether we sent all the logs via READ_FROM_BEGINNING into a file
# (HAS_READ_FROM_BEGINNING). This ensures that if Joe Cool is restarted, we
# don't re-send all the logs.

HAS_READ_FROM_BEGINNING=/tmp/read-from-beginning

TAIL_OPT="-tail=true"

if [[ -n "$READ_FROM_BEGINNING" ]]; then
  echo "READ_FROM_BEGINNING is TRUE"
fi

if [[ ! -f "$HAS_READ_FROM_BEGINNING" ]]; then
  echo "FILE NOT PRESENT is TRUE"
fi

if [[ -n "$READ_FROM_BEGINNING" ]] && [[ ! -f "$HAS_READ_FROM_BEGINNING" ]]; then
  touch "$HAS_READ_FROM_BEGINNING"
  TAIL_OPT=""
fi

CONFIG=logstash-forwarder/logstash-forwarder.config

if [[ -n "${JSON_CONFIGURATION:-}" ]]; then
  ruby generate-config.rb > "$CONFIG"
else
  : ${CONTAINERS_TO_MONITOR:?"Error: environment variable CONTAINERS_TO_MONITOR should contain a comma-separated list of container ids."}
  erb logstash-forwarder.config.erb > "$CONFIG"
fi

cd logstash-forwarder
echo "$LOGSTASH_CERTIFICATE" > logstash.crt

exec ./logstash-forwarder -config logstash-forwarder.config -max-line-bytes=101376 $TAIL_OPT
