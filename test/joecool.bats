#!/usr/bin/env bats

setup() {
  mkdir /tmp/dockerlogs
  mkdir /tmp/activitylogs
  mkdir /tmp/test-support
}

teardown() {
  rm -rf /tmp/dockerlogs
  rm -rf /tmp/activitylogs
  rm -rf /tmp/test-support
  rm -f /tmp/read-from-beginning
  killall -KILL nc || true
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

@test "Joe Cool does not require the /tmp/activitylogs directory to exist" {
  export LOGSTASH_ENDPOINT=foo
  export LOGSTASH_CERTIFICATE=bar
  export CONTAINERS_TO_MONITOR=baz
  rm -rf /tmp/activitylogs
  run timeout -t 1 /bin/bash run-joe-cool.sh
  [[ "$output" =~ "prospectors initialised" ]]
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

  touch /tmp/activitylogs/foodeadbeef-json.log
  touch /tmp/activitylogs/bardeadbeef-json.log

  # CONTAINERS_TO_MONITOR sets this Joe Cool instance up to monitor containers that start
  # with foo, fee, or fuu. We'll just verify that setting up a fake server listening on
  # 127.0.0.1:5555 and the environment variables we've set are enough to bring up a Joe
  # Cool tailing the correct files (only foodeadbeef).

  echo "no-op" | nc -l -p 5555 &
  run timeout -t 1 /bin/bash run-joe-cool.sh
  [[ "$output" =~ "Launching harvester on new file: /tmp/dockerlogs/foodeadbeef/foodeadbeef-json.log" ]]
  [[ "$output" =~ "Launching harvester on new file: /tmp/activitylogs/foodeadbeef-json.log" ]]
  [[ ! "$output" =~ "Launching harvester on new file: /tmp/dockerlogs/bardeadbeef/bardeadbeef-json.log" ]]
  [[ ! "$output" =~ "Launching harvester on new file: /tmp/activitylogs/bardeadbeef-json.log" ]]
}

@test "Joe Cool forwards logs to a logstash instance (JSON configuration)" {
  openssl req -x509 -batch -nodes -newkey rsa:2048 -out /tmp/test-support/jerry.crt

  export JSON_CONFIGURATION=1
  export LOGSTASH_ENDPOINT=localhost:5555
  export LOGSTASH_CERTIFICATE=`cat /tmp/test-support/jerry.crt`
  export CONTAINERS='["foo", "fee", "fuu"]'
  export FIELDS='{}'

  # Set up fake Docker logs
  mkdir /tmp/dockerlogs/foodeadbeef
  mkdir /tmp/dockerlogs/bardeadbeef
  touch /tmp/dockerlogs/foodeadbeef/foodeadbeef-json.log
  touch /tmp/dockerlogs/bardeadbeef/bardeadbeef-json.log

  touch /tmp/activitylogs/foodeadbeef-json.log
  touch /tmp/activitylogs/bardeadbeef-json.log

  echo "no-op" | nc -l -p 5555 &
  run timeout -t 1 /bin/bash run-joe-cool.sh

  echo "$output"

  [[ "$output" =~ "Launching harvester on new file: /tmp/dockerlogs/foodeadbeef/foodeadbeef-json.log" ]]
  [[ "$output" =~ "Launching harvester on new file: /tmp/activitylogs/foodeadbeef-json.log" ]]
  [[ ! "$output" =~ "Launching harvester on new file: /tmp/dockerlogs/bardeadbeef/bardeadbeef-json.log" ]]
  [[ ! "$output" =~ "Launching harvester on new file: /tmp/activitylogs/bardeadbeef-json.log" ]]
}

@test "Joe Cool sends all logs once if READ_FROM_BEGINNING is set" {
  openssl req -x509 -batch -nodes -newkey rsa:2048 -out /tmp/test-support/jerry.crt
  export LOGSTASH_ENDPOINT=localhost:5555
  export LOGSTASH_CERTIFICATE=`cat /tmp/test-support/jerry.crt`
  export CONTAINERS_TO_MONITOR=deadbeef
  export READ_FROM_BEGINNING=true

  # Set up fake Docker logs
  mkdir /tmp/dockerlogs/deadbeef
  echo 0123456789 > /tmp/dockerlogs/deadbeef/deadbeef-json.log

  echo 0123456789 > /tmp/activitylogs/deadbeef-json.log

  # Our fake logs have 10 characters in them. Since we set READ_FROM_BEGINNING,
  # the logstash forwarder should report that its file offset is 0.
  run timeout -t 1 /bin/bash run-joe-cool.sh
  [[ "$output" =~ "tail (on-rotation):  false" ]]
  [[ "$output" =~ "Launching harvester on new file: /tmp/dockerlogs/deadbeef/deadbeef-json.log" ]]
  [[ "$output" =~ "harvest: \"/tmp/dockerlogs/deadbeef/deadbeef-json.log\" (offset snapshot:0)" ]]
  [[ "$output" =~ "harvest: \"/tmp/activitylogs/deadbeef-json.log\" (offset snapshot:0)" ]]

  # If we run a second time, then Joecool should *not* send the logs again.
  run timeout -t 1 /bin/bash run-joe-cool.sh
  [[ "$output" =~ "tail (on-rotation):  true" ]]
  [[ "$output" =~ "Launching harvester on new file: /tmp/dockerlogs/deadbeef/deadbeef-json.log" ]]
  [[ "$output" =~ "harvest: (tailing) \"/tmp/dockerlogs/deadbeef/deadbeef-json.log\" (offset snapshot:11)" ]]
}

@test "Joe Cool tails logs if the READ_FROM_BEGINNING flag isn't set" {
  openssl req -x509 -batch -nodes -newkey rsa:2048 -out /tmp/test-support/jerry.crt
  export LOGSTASH_ENDPOINT=localhost:5555
  export LOGSTASH_CERTIFICATE=`cat /tmp/test-support/jerry.crt`
  export CONTAINERS_TO_MONITOR=deadbeef

  # Set up fake Docker logs
  mkdir /tmp/dockerlogs/deadbeef
  echo 0123456789 > /tmp/dockerlogs/deadbeef/deadbeef-json.log

  # Our fake logs have 10 characters in them. Since we didn't set READ_FROM_BEGINNING,
  # the logstash forwarder should report that its file offset is 11.
  run timeout -t 1 /bin/bash run-joe-cool.sh
  [[ "$output" =~ "tail (on-rotation):  true" ]]
  [[ "$output" =~ "Launching harvester on new file: /tmp/dockerlogs/deadbeef/deadbeef-json.log" ]]
  [[ "$output" =~ "harvest: (tailing) \"/tmp/dockerlogs/deadbeef/deadbeef-json.log\" (offset snapshot:11)" ]]
}

@test "Joe Cool does not truncate lines that are at most 99KB" {
  openssl req -x509 -batch -nodes -newkey rsa:2048 -out /tmp/test-support/jerry.crt
  export LOGSTASH_ENDPOINT=localhost:5555
  export LOGSTASH_CERTIFICATE=`cat /tmp/test-support/jerry.crt`
  export CONTAINERS_TO_MONITOR=deadbeef
  export READ_FROM_BEGINNING=1

  # Set up fake Docker logs with exactly 99 KB of data on one line.
  mkdir /tmp/dockerlogs/deadbeef
  printf "%0.s-" {1..101376} > /tmp/dockerlogs/deadbeef/deadbeef-json.log

  # We haven't gone over our limit of 99KB in a line, so we should not see truncation.
  run timeout -t 1 /bin/bash run-joe-cool.sh

  [[ "$output" =~ "max-line-bytes:      101376" ]]
  [[ ! "$output" =~ "harvest: max line length reached, ignoring rest of line." ]]
}

@test "Joe Cool will cut you if you try to send lines longer than 99KB" {
  openssl req -x509 -batch -nodes -newkey rsa:2048 -out /tmp/test-support/jerry.crt
  export LOGSTASH_ENDPOINT=localhost:5555
  export LOGSTASH_CERTIFICATE=`cat /tmp/test-support/jerry.crt`
  export CONTAINERS_TO_MONITOR=deadbeef
  export READ_FROM_BEGINNING=1

  # Set up fake Docker logs with more than 99 KB of data on one line.
  mkdir /tmp/dockerlogs/deadbeef
  printf "%0.s-" {1..101377} > /tmp/dockerlogs/deadbeef/deadbeef-json.log

  # We've gone over our limit of 99KB in a line, so we should see a truncation.
  run timeout -t 1 /bin/bash run-joe-cool.sh

  [[ "$output" =~ "max-line-bytes:      101376" ]]
  [[ "$output" =~ "harvest: max line length reached, ignoring rest of line." ]]
}
