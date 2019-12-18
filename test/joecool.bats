#!/usr/bin/env bats

setup() {
  mkdir /tmp/dockerlogs
  mkdir /tmp/activitylogs
  mkdir /tmp/test-support
}

set_cert() {
  export LOGSTASH_CERTIFICATE=$(openssl req -x509 -batch -nodes -newkey rsa:2048 -subj /CN=localhost/)
}

start_redis() {
  echo "requirepass ${TAIL_PASSWORD}" >> "${BATS_TEST_DIRNAME}/redis.conf"
  redis-server "${BATS_TEST_DIRNAME}/redis.conf" &
}

teardown() {
  rm -rf /tmp/dockerlogs
  rm -rf /tmp/activitylogs
  rm -rf /tmp/test-support
  rm -f /tmp/read-from-beginning
  killall -KILL nc || true
  pkill -KILL redis-server || true
}

@test "Joe Cool requires the LOGSTASH_ENDPOINT environment variable to be set" {
  set_cert
  export CONTAINERS="[\"baz\"]"
  run /bin/bash run-joe-cool.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "LOGSTASH_ENDPOINT" ]]
}

@test "Joe Cool requires the LOGSTASH_CERTIFICATE environment variable to be set" {
  export LOGSTASH_ENDPOINT=foo
  export CONTAINERS="[\"baz\"]"
  run /bin/bash run-joe-cool.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "LOGSTASH_CERTIFICATE" ]]
}

@test "Joe Cool requires the CONTAINERS environment variable to be set" {
  export LOGSTASH_ENDPOINT=foo
  set_cert
  run /bin/bash run-joe-cool.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "CONTAINERS" ]]
}

@test "Joe Cool requires the /tmp/dockerlogs directory to exist" {
  export LOGSTASH_ENDPOINT=foo
  set_cert
  export CONTAINERS="[\"baz\"]"
  rm -rf /tmp/dockerlogs
  run /bin/bash run-joe-cool.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "/tmp/dockerlogs" ]]
}

@test "Joe Cool does not require the /tmp/activitylogs directory to exist" {
  export LOGSTASH_ENDPOINT=foo
  set_cert
  export CONTAINERS="[\"baz\"]"
  rm -rf /tmp/activitylogs
  run timeout -t 1 /bin/bash run-joe-cool.sh
  echo $output
  [[ "$output" =~ "Loading and starting Inputs completed. Enabled inputs: 2" ]]
}

@test "Joe Cool sends all logs once if READ_FROM_BEGINNING is set" {
  set_cert

  # Disable SSL. Running stunnel here requires more overhead than it is
  # worth, so we will just test forwarding to regular old Redis.
  export DISABLE_SSL=1

  export JSON_CONFIGURATION=1
  export LOGSTASH_ENDPOINT=localhost
  export TAIL_PORT=6379
  export CONTAINERS="[\"baz\"]"
  export TAIL_PASSWORD=foo123
  export READ_FROM_BEGINNING=true

  # Set up fake Docker logs
  mkdir /tmp/dockerlogs/baz
  mkdir /tmp/dockerlogs/ignore
  touch /tmp/dockerlogs/baz/baz-json.log
  touch /tmp/dockerlogs/ignore/ignore-json.log

  start_redis

  echo "{\"a\": 1}" >> /tmp/dockerlogs/baz/baz-json.log
  # This shouldn't be picked up by filebeat, since it shouldn't
  # be watching this file.
  echo "{\"b\": 2}" >> /tmp/dockerlogs/ignore/ignore-json.log

  run timeout -t 10 /bin/bash run-joe-cool.sh

  out="$(redis-cli -n 1 -a ${TAIL_PASSWORD} --raw llen filebeat)"
  echo "Out is: ${out}"
  [ "$out" = "1" ]
}

@test "Joe Cool tails logs if the READ_FROM_BEGINNING flag is not set" {
  set_cert

  # Disable SSL. Running stunnel here requires more overhead than it is
  # worth, so we will just test forwarding to regular old Redis.
  export DISABLE_SSL=1

  export JSON_CONFIGURATION=1
  export LOGSTASH_ENDPOINT=localhost
  export TAIL_PORT=6379
  export CONTAINERS="[\"bazzzzz\"]"
  export TAIL_PASSWORD=foo123

  # Set up fake Docker logs
  mkdir /tmp/dockerlogs/bazzzzz
  mkdir /tmp/dockerlogs/ignore
  touch /tmp/dockerlogs/bazzzzz/bazzzzz-json.log
  touch /tmp/dockerlogs/ignore/ignore-json.log

  start_redis

  echo "{\"a\": 1}" >> /tmp/dockerlogs/bazzzzz/bazzzzz-json.log

  run timeout -t 10 /bin/bash run-joe-cool.sh

  out="$(redis-cli -n 1 -a ${TAIL_PASSWORD} --raw llen filebeat)"
  echo "Out is: ${out}"
  [ "$out" = "0" ]
}

@test "Joe Cool does not truncate lines that are at most 99KB" {
  set_cert

  # Disable SSL. Running stunnel here requires more overhead than it is
  # worth, so we will just test forwarding to regular old Redis.
  export DISABLE_SSL=1

  export JSON_CONFIGURATION=1
  export LOGSTASH_ENDPOINT=localhost
  export TAIL_PORT=6379
  export CONTAINERS="[\"bazzz\"]"
  export TAIL_PASSWORD=foo123
  export READ_FROM_BEGINNING=true

  # Set up fake Docker logs
  mkdir /tmp/dockerlogs/bazzz
  touch /tmp/dockerlogs/bazzz/bazzz-json.log

  start_redis

  # Filebeat considers the metadata that it packages with the log
  # line as part of the log line, so we can't just go straight for
  # the full 99KB in just the log message, hence the large, but < 99KB
  # number.
  random=$(ruby -e "print 'a'*101375")
  echo $random > /tmp/dockerlogs/bazzz/bazzz-json.log

  run timeout -t 10 /bin/bash run-joe-cool.sh

  out="$(redis-cli -n 1 -a ${TAIL_PASSWORD} --raw llen filebeat)"
  echo "Out is: ${out}"
  [ "$out" = "1" ]

  out="$(redis-cli -n 1 -a ${TAIL_PASSWORD} --raw lrange filebeat 0 1)"
  echo "Out is: ${out}"
  ! [[ "$out" =~ "\"flags\":[\"truncated\"]" ]]
}

@test "Joe Cool will cut you if you try to send lines longer than 99KB" {
  set_cert

  # Disable SSL. Running stunnel here requires more overhead than it is
  # worth, so we will just test forwarding to regular old Redis.
  export DISABLE_SSL=1

  export JSON_CONFIGURATION=1
  export LOGSTASH_ENDPOINT=localhost
  export TAIL_PORT=6379
  export CONTAINERS="[\"bazz\"]"
  export TAIL_PASSWORD=foo123
  export READ_FROM_BEGINNING=true

  # Set up fake Docker logs
  mkdir /tmp/dockerlogs/bazz
  touch /tmp/dockerlogs/bazz/bazz-json.log

  start_redis

  random=$(ruby -e "print 'a'*101377 + 'b'")
  echo "{\"log\": \"$random\", \"stream\": \"stdout\"}" > /tmp/dockerlogs/bazz/bazz-json.log

  run timeout -t 10 /bin/bash run-joe-cool.sh

  out="$(redis-cli -n 1 -a ${TAIL_PASSWORD} --raw llen filebeat)"
  echo "Out is: ${out}"
  [ "$out" = "1" ]

  out="$(redis-cli -n 1 -a ${TAIL_PASSWORD} --raw lrange filebeat 0 1)"
  echo "Out is: ${out}"
  [[ "$out" =~ "\"flags\":[\"truncated\"]" ]]
  [[ "$out" =~ "${random:0:10}" ]]

  run ruby -e "require 'json'; JSON.parse('${out}')"
  [ "$status" -eq 0 ]
}

