FROM quay.io/aptible/ubuntu:14.04

# Install git, golang and ruby. Clone the logstash-forwarder repository.
RUN apt-get update && \
    apt-get install -y git golang ruby && \
    apt-get clean && \
    git clone git://github.com/elasticsearch/logstash-forwarder.git

# Build logstash-forwarder from source, verify the resulting SHA against a golden SHA.
RUN cd logstash-forwarder && git checkout tags/v0.3.1 && go build && \
    echo "f7189190e21c3eb99b43fb429650ec0abfbf917a  logstash-forwarder" | sha1sum -c -

# Add the logstash-forwarder config template and the bash script to run Joe Cool.
ADD templates/logstash-forwarder.config.erb logstash-forwarder.config.erb
ADD bin/run-joe-cool.sh run-joe-cool.sh

# Run tests.
ADD test /tmp/test
RUN bats /tmp/test

CMD ["/bin/bash", "run-joe-cool.sh"]
