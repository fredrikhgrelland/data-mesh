# versions
PRESTO_VERSION := 333

# start commands
up:
	vagrant up --provision

# clean commands
clean: 
	vagrant destroy -f

# start proxies
connect-to-hive:
	consul connect proxy -token ${CONSUL_MASTER_TOKEN} -service user -upstream hive-server:8070 -log-level debug
connect-to-presto:
	consul connect proxy -token ${CONSUL_MASTER_TOKEN} -service user -upstream presto:8080 -log-level debug
connect-to-minio:
	consul connect proxy -token ${CONSUL_MASTER_TOKEN} -service user -upstream minio:8090 -log-level debug
connect-to-hue:
	consul connect proxy -token ${CONSUL_MASTER_TOKEN} -service user -upstream hue-server:8888 -log-level debug

download-presto-cli:
	wget https://repo1.maven.org/maven2/io/prestosql/presto-cli/${PRESTO_VERSION}/presto-cli-${PRESTO_VERSION}-executable.jar
	mv presto-cli-${PRESTO_VERSION}-executable.jar presto && chmod +x presto &&	mkdir -p ./bin && mv presto ./bin

presto-cli:
	./bin/presto  --http-proxy 127.0.0.1:8080 --catalog hive --schema default
