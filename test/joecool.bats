#!/usr/bin/env bats

setup() {
  mkdir /tmp/dockerlogs
  mkdir /tmp/test-support
}

teardown() {
  rm -rf /tmp/dockerlogs
  rm -rf /tmp/test-support
}

@test "Joe Cool requires the LOGSTASH_ENDPOINT environment variable to be set" {
  export LOGSTASH_CERTIFICATE=foo
  export CONTAINERS_TO_MONITOR=bar
  run /bin/bash run-joe-cool.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "LOGSTASH_ENDPOINT" ]]
}

@test "Joe Cool requires the LOGSTASH_CERTIFICATE environment variable to be set" {
  export LOGSTASH_ENDPOINT=foo
  export CONTAINERS_TO_MONITOR=bar
  run /bin/bash run-joe-cool.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "LOGSTASH_CERTIFICATE" ]]
}

@test "Joe Cool requires the CONTAINERS_TO_MONITOR environment variable to be set" {
  export LOGSTASH_ENDPOINT=foo
  export LOGSTASH_CERTIFICATE=bar
  run /bin/bash run-joe-cool.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "CONTAINERS_TO_MONITOR" ]]
}

@test "Joe Cool requires the /tmp/dockerlogs directory to exist" {
  export LOGSTASH_ENDPOINT=foo
  export LOGSTASH_CERTIFICATE=bar
  export CONTAINERS_TO_MONITOR=baz
  rm -rf /tmp/dockerlogs
  run /bin/bash run-joe-cool.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "/tmp/dockerlogs" ]]
}

@test "Joe Cool forwards logs to a logstash instance" {
  openssl req -x509 -batch -nodes -newkey rsa:2048 -out /tmp/test-support/jerry.crt 
  export LOGSTASH_ENDPOINT=localhost:5555
  export LOGSTASH_CERTIFICATE=`cat /tmp/test-support/jerry.crt`
  export CONTAINERS_TO_MONITOR=foo,fee,fuu

  # Set up fake Docker logs
  mkdir /tmp/dockerlogs/foodeadbeef
  mkdir /tmp/dockerlogs/bardeadbeef
  touch /tmp/dockerlogs/foodeadbeef/foodeadbeef-json.log
  touch /tmp/dockerlogs/bardeadbeef/bardeadbeef-json.log

  # CONTAINERS_TO_MONITOR sets this Joe Cool instance up to monitor containers that start
  # with foo, fee, or fuu. We'll just verify that setting up a fake server listening on
  # 127.0.0.1:5555 and the environment variables we've set are enough to bring up a Joe
  # Cool tailing the correct files (only foodeadbeef).

  tcpserver 127.0.0.1 5555 echo "no-op" &
  run timeout 1s /bin/bash run-joe-cool.sh
  [[ "$output" =~ "Starting harvester: /tmp/dockerlogs/foodeadbeef/foodeadbeef-json.log" ]]
  [[ ! "$output" =~ "Starting harvester: /tmp/dockerlogs/bardeadbeef/bardeadbeef-json.log" ]]
}
