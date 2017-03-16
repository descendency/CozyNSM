FROM kibana:latest
ADD x-pack-5.2.1.zip /tmp/
ADD kibana.yml /etc/kibana/kibana.yml
RUN ./usr/share/kibana/bin/kibana-plugin install file:///tmp/x-pack-5.2.1.zip
