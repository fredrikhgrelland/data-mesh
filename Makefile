#Portability
MAC_DOCKER := 192.168.0.190
LINUX_DOCKER := 172.17.0.1
HOST_DOCKER := ${LINUX_DOCKER}
NETWORK_INTERFACE_MAC := en0
NETWORK_INTERFACE_LINUX := docker0
NETWORK_INTERFACE := ${NETWORK_INTERFACE_LINUX}
PATH  := $(PWD)/bin:$(PATH)
#SHELL := env PATH=$(PATH) /bin/bash

#Versions
CONSUL_MASTER_TOKEN := b6e29626-e23d-98b4-e19f-c71a96fbdef7
CONSUL_USER_TOKEN := 47ec8d90-bf0a-4c18-8506-8d492b131b6d
NOMAD_VERSION := 0.11.2
CONSUL_VERSION := 1.8.0-beta2
PRESTO_VERSION := 333

exports:
	@echo "export CONSUL_HTTP_TOKEN=${CONSUL_MASTER_TOKEN} #MASTER"
	@echo "export CONSUL_HTTP_TOKEN=${CONSUL_USER_TOKEN} #USER"
	@echo "export NOMAD_ADDR=http://${HOST_DOCKER}:4646"

docker:
	$(MAKE) -C docker build

download: download-consul download-nomad download-presto download-minio-mc version
download-consul:
	rm -f nomad_*.zip
	wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
	unzip -o consul_${CONSUL_VERSION}_linux_amd64.zip && rm -f consul_${CONSUL_VERSION}_linux_amd64.zip && chmod +x consul && mkdir -p ./bin && mv consul ./bin

download-nomad:
	rm -f nomad_*.zip
	wget https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip
	unzip -o nomad_${NOMAD_VERSION}_linux_amd64.zip && rm -f nomad_${NOMAD_VERSION}_linux_amd64.zip && chmod +x nomad && mkdir -p ./bin && mv nomad ./bin

download-presto:
	wget https://repo1.maven.org/maven2/io/prestosql/presto-cli/${PRESTO_VERSION}/presto-cli-${PRESTO_VERSION}-executable.jar
	mv presto-cli-${PRESTO_VERSION}-executable.jar presto && chmod +x presto &&	mkdir -p ./bin && mv presto ./bin

download-minio-mc:
	wget https://dl.min.io/client/mc/release/linux-amd64/mc
	chmod +x mc && mkdir -p ./bin && mv mc ./bin

version:
	@echo "Versions of binaries - if not as expected, run make download"
	@consul version && nomad version && presto --version && mc --version

build-certificate-handler:
	docker build . -t certificate-handler:v0.1

prereq:
	sudo systemctl stop ufw
	sudo mkdir -p /opt/cni/bin && curl -s -L https://github.com/containernetworking/plugins/releases/download/v0.8.4/cni-plugins-linux-amd64-v0.8.4.tgz | sudo tar xz -C /opt/cni/bin

kill:
	- sudo pkill -f consul
	- sudo pkill -f nomad

clean: kill
	sudo systemctl start ufw

consul: consul_start consul_config

.ONESHELL .PHONY:
consul_config:
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X PUT -d '{"Name": "anonymous", "Rules": "node_prefix \"\" { policy = \"read\" } service_prefix \"\" { policy = \"read\" }"}' http://127.0.0.1:8500/v1/acl/policy
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X PUT -d '{"Policies": [ { "Name": "anonymous" } ]}' http://127.0.0.1:8500/v1/acl/token/00000000-0000-0000-0000-000000000002
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X PUT -d '{"SecretID": "${CONSUL_USER_TOKEN}", "Description": "Service identity token for user", "ServiceIdentities": [ { "ServiceName": "user" } ]}' http://127.0.0.1:8500/v1/acl/token

consul_start:
	sudo ./bin/consul agent -dev -config-file=consul_config.json

nomad:
	sudo ./bin/nomad agent -dev-connect -consul-token=${CONSUL_MASTER_TOKEN} -bind=${HOST_DOCKER} -network-interface=${NETWORK_INTERFACE} -consul-address=127.0.0.1:8500

presto: presto presto-service-update

presto:
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad stop -purge presto | true
	sleep 2
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad run nomad-jobs/presto-connect.hcl
	sleep 10
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "presto", "DestinationName": "hive-metastore", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "presto", "DestinationName": "minio", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions

hive:
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad stop -purge hive | true
	sleep 2
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad run nomad-jobs/hive-connect.hcl
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "hivebeeline", "DestinationName": "hive-server", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "hive-server", "DestinationName": "hive-metastore", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "hive-metastore", "DestinationName": "hive-database", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "presto", "DestinationName": "hive-metastore", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions

minio:
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad stop -purge minio | true
	sleep 2
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad run nomad-jobs/minio-connect.hcl
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "presto", "DestinationName": "minio", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "hive-metastore", "DestinationName": "minio", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "hive-server", "DestinationName": "minio", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions

presto-service-update:
	sleep 10
	while true
	do
		PRESTO_IP=$$(curl -s http://127.0.0.1:8500/v1/catalog/service/presto | jq -r '.[0] | "\(.ServiceAddress)"')
		PRESTO_PORT=$$(curl -s http://127.0.0.1:8500/v1/catalog/service/presto | jq -r '.[0] | "\(.ServicePort)"')
		if [ "$${PRESTO_PORT}" != "" ]; then break; else sleep 1; fi
	done
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X PUT -d "{ \"Name\": \"presto\", \"Service\": \"presto\", \"Port\": $${PRESTO_PORT}, \"Address\": \"$${PRESTO_IP}\", \"connect\": { \"native\": true } }" http://127.0.0.1:8500/v1/agent/service/register?replace-existing-checks=true

exec-presto-coordinator:
	docker exec -it $$(docker ps --filter="ancestor=presto:330-SNAPSHOT" --filter="name=coordinator" --format "{{.ID}}") bash

connect-allow-user-to-presto:
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "user", "DestinationName": "presto", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions
connect-allow-user-to-hive:
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "user", "DestinationName": "hive-server", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions
connect-allow-user-to-minio:
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "user", "DestinationName": "minio", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions
connect-allow-user-to-hue:
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "user", "DestinationName": "hue-server", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions


proxy-user-to-hive:
	consul connect proxy -token ${CONSUL_USER_TOKEN} -service user -upstream hive-server:8070 -log-level debug
proxy-user-to-presto:
	consul connect proxy -token ${CONSUL_USER_TOKEN} -service user -upstream presto:8080 -log-level debug
proxy-user-to-minio:
	consul connect proxy -token ${CONSUL_USER_TOKEN} -service user -upstream minio:8090 -log-level debug
proxy-user-to-hue:
	consul connect proxy -token ${CONSUL_USER_TOKEN} -service user -upstream hue-server:8888 -log-level debug

proxy-test-user-to-presto:
	curl -s http://127.0.0.1:8080/v1/info | jq .
	curl -s http://127.0.0.1:8080/v1/cluster | jq .

presto-cli-proxy:
	./presto  --http-proxy 127.0.0.1:8080 --catalog tpch --schema tiny

presto-cli-proxy-read:
	./presto  --http-proxy 127.0.0.1:8080 --catalog tpch --schema tiny --debug --execute 'SELECT * FROM customer LIMIT 20;'

presto-cli-proxy-write:
	./presto  --http-proxy 127.0.0.1:8080 --catalog tpch --schema tiny --debug --execute 'CREATE TABLE hive.default.customer AS SELECT * FROM customer;'

presto-cli-direct:
	PRESTO_PORT=$$(curl -s -H X-Consul-Token:${CONSUL_USER_TOKEN} http://127.0.0.1:8500/v1/catalog/service/presto | jq -r '.[0] | (.ServicePort)')
	./presto --server https://presto:$${PRESTO_PORT} --keystore-path=test.jks --keystore-password=changeit --catalog tpch --schema tiny --debug --execute 'SELECT * FROM customer LIMIT 20;'

countdash:
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad stop -purge countdash | true
	sleep 2
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad run nomad/connect-countdash.hcl

curl-sql-direct:
	nextURI=$$(curl -s -k --cacert root.pem --cert test.pem --key test.key -X POST -H X-Presto-User:test -d 'SHOW CATALOGS' https://presto:8443/v1/statement | jq -r .nextUri)
	sleep 1
	nextURI=$$(curl -s -k --cacert root.pem --cert test.pem --key test.key -X GET $$nextURI | jq -r .nextUri)
	sleep 1
	nextURI=$$(curl -s -k --cacert root.pem --cert test.pem --key test.key -X GET $$nextURI | jq -r .nextUri)
	sleep 1
	nextURI=$$(curl -s -k --cacert root.pem --cert test.pem --key test.key -X GET $$nextURI | jq -r .nextUri)
	curl -s -k --cacert root.pem --cert test.pem --key test.key -X GET $$nextURI | jq .

curl-sql-proxy:
	nextURI=$$(curl -s -X POST -H X-Forwarded-Proto:http -H X-Presto-User:test -d 'SHOW CATALOGS' http://127.0.0.1:8888/v1/statement | jq -r .nextUri)
	sleep 1
	nextURI=$$(curl -s -H X-Forwarded-Proto:http -X GET $$nextURI | jq -r .nextUri)
	sleep 1
	nextURI=$$(curl -s -H X-Forwarded-Proto:http -X GET $$nextURI | jq -r .nextUri)
	sleep 1
	nextURI=$$(curl -s -H X-Forwarded-Proto:http -X GET $$nextURI | jq -r .nextUri)
	curl -s -H X-Forwarded-Proto:http -X GET $$nextURI | jq .


presto-local-cn-presto:
	PRESTO_ADDR=$$(curl -s http://127.0.0.1:8500/v1/catalog/service/presto | jq -r '.[0] | "https://\(.ServiceAddress):\(.ServicePort)/v1/info"')
	curl -s -k --cacert bundle.pem --cert leaf.pem --key leaf.key $${PRESTO_ADDR} | jq .

presto-local-cn-test:
	PRESTO_ADDR=$$(curl -s http://127.0.0.1:8500/v1/catalog/service/presto | jq -r '.[0] | "https://\(.ServiceAddress):\(.ServicePort)/v1/info"')
	curl -s -i -k --cacert bundle.pem --cert test.pem --key test.key $${PRESTO_ADDR}

minio-testdata:
	mc config host add minio-connect-proxy http://127.0.0.1:8090 minioadmin minioadmin
	mc cp test/data/dummy.csv minio-connect-proxy/hive/warehouse/iris/dummy.csv

hive-testdata:
example-csv:
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad stop -purge example-csv | true
	sleep 2
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad run nomad-jobs/example-csv.hcl
	sleep 10
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "testdata-csv", "DestinationName": "minio", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "testdata-csv", "DestinationName": "hive-server", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions
hue1:
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad stop -purge hue | true
	sleep 2
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad run nomad-jobs/hue-connect.hcl
	sleep 10
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "hue-server", "DestinationName": "presto", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions
	curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X POST -d '{"SourceName": "hue-server", "DestinationName": "hue-database", "SourceType": "consul", "Action": "allow"}' http://127.0.0.1:8500/v1/connect/intentions
up: minio hive presto1 example-csv
down:
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad stop -purge example-csv | true
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad stop -purge presto | true
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad stop -purge hive | true
	NOMAD_ADDR=http://${HOST_DOCKER}:4646 nomad stop -purge minio | true
