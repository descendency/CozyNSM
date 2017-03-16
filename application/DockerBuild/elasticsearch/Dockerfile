FROM elasticsearch
ADD elasticsearch.yml /etc/elastcisearch/elasticsearch.yml
ADD x-pack-5.2.1.zip /tmp/
RUN echo y | /usr/share/elasticsearch/bin/elasticsearch-plugin install file:///tmp/x-pack-5.2.1.zip -s

####If you have a license for X-Pack
#ADD xpacklicense.json /tmp/


RUN service elasticsearch stop
RUN service elasticsearch start

####If you have a license for X-Pack
#RUN echo “changeme” curl -XPUT -u elastic 'http://localhost:9200/_xpack/license' -d @/tmp/xpacklicense.json
