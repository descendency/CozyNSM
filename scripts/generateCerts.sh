DOMAIN=$1
PASS=$2

rm -rf certs
sysctl -w vm.max_map_count=1073741824
docker run --restart=always -itd --name escerts elasticsearch
docker cp elasticsearch/elasticsearch_basic.yml escerts:/usr/share/elasticsearch/config/elasticsearch.yml
docker restart escerts
docker cp elasticsearch/instances.yml escerts:/usr/share/elasticsearch/config/instances.yml
docker exec -itu root escerts /usr/share/elasticsearch/bin/elasticsearch-certutil cert ca --pem  --silent --in config/instances.yml --out certs.zip --pass $PASS
mkdir -p certs
docker cp escerts:/usr/share/elasticsearch/certs.zip certs/certs.zip
unzip certs/certs.zip -d certs
docker rm -f -v escerts
################################################################################
# Elastic Certificates
################################################################################
sysctl -w vm.max_map_count=1073741824
docker run --restart=always -itd --name escerts elasticsearch
docker cp elasticsearch/elasticsearch_basic.yml escerts:/usr/share/elasticsearch/config/elasticsearch.yml
docker restart escerts
docker exec -i escerts bin/elasticsearch-certutil ca --out elastic-certificates.p12 --pass $PASS
docker exec -i escerts bin/elasticsearch-certutil cert --pass $PASS --ca-pass $PASS --ca elastic-certificates.p12 --out elastic-certificates-final.p12
mkdir certs
docker cp escerts:/usr/share/elasticsearch/elastic-certificates-final.p12 certs/elastic-certificates.p12
docker rm -f -v escerts

################################################################################
# Nginx Certificates
################################################################################
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout nginx/nginx.key -out nginx/nginx.crt -subj "/C=US/ST=/L=/O=CozyStack/OU=CozyStack/CN=$DOMAIN"
openssl req -out nginx/nginx.csr -key nginx/nginx.key -new -subj "/C=US/ST=/L=/O=CozyStack/OU=CozyStack/CN=$DOMAIN"
