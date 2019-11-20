#!/bin/bash
set -o errexit

: ${CONTAINERS:?"Error: environment variable CONTAINERS should contain a JSON-formatted list of container ids."}
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
export TAIL=1
if [[ -n "$READ_FROM_BEGINNING" ]]; then
  echo "READ_FROM_BEGINNING is TRUE"
fi
if [[ ! -f "$HAS_READ_FROM_BEGINNING" ]]; then
  echo "FILE NOT PRESENT is TRUE"
fi
if [[ -n "$READ_FROM_BEGINNING" ]] && [[ ! -f "$HAS_READ_FROM_BEGINNING" ]]; then
  touch "$HAS_READ_FROM_BEGINNING"
  export TAIL=0
fi

CONFIG=${FILEBEAT_HOME}/filebeat.yml
erb ${FILEBEAT_HOME}/filebeat.yml.erb > ${CONFIG}
echo "$LOGSTASH_CERTIFICATE" > ${FILEBEAT_HOME}/logstash.crt


exec ${FILEBEAT_HOME}/filebeat -c ${CONFIG} -e
