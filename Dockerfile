FROM quay.io/aptible/ubuntu:14.04

# Install git, golang and ruby. Clone the logstash-forwarder repository.
RUN apt-get update && \
    apt-get install -y git golang ruby && \
    apt-get clean && \
    git clone git://github.com/aaw/logstash-forwarder.git && \
    cd logstash-forwarder && \
    git reset --hard 141d0c5d6077fa9dfbd3b6ac6b37eb0a2bd81498

# Build logstash-forwarder from source, verify the resulting SHA against a golden SHA.
RUN cd logstash-forwarder && \
    go build && \
    echo "e582ccd6bf851bfd63fa349004170afc81fec37d logstash-forwarder" | sha1sum -c -

# Add the logstash-forwarder config template and the bash script to run Joe Cool.
ADD templates/logstash-forwarder.config.erb logstash-forwarder.config.erb
ADD bin/run-joe-cool.sh run-joe-cool.sh

# Run tests.
ADD test /tmp/test
RUN bats /tmp/test

# Any docker logs need to be mounted at /tmp/dockerlogs. Typically, this means that
# a volume should be created mapping /var/lib/docker/containers to /tmp/dockerlogs
# in the container.
VOLUME ["/tmp/dockerlogs"]

CMD ["/bin/bash", "run-joe-cool.sh"]
