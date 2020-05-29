branch := $( shell git rev-parse --abbrev-ref HEAD)

.ONESHELL .PHONY: hadoop hive pem-to-p12 all build push
.DEFAULT_GOAL := build

all: build push

build: hadoop hive pem-to-p12

custom_ca:
ifdef CUSTOM_CA
	cp -rf $(CUSTOM_CA)/* ./hadoop/ca_certificates/ || cp -f $(CUSTOM_CA) ./hadoop/ca_certificates/
endif

hadoop: custom_ca
	docker build ./hadoop -t fredrikhgrelland/hadoop:3.1.0
	docker tag  fredrikhgrelland/hadoop:3.1.0 fredrikhgrelland/hadoop:latest

hive:
	docker build ./hive -t fredrikhgrelland/hive:3.1.0
	docker tag  fredrikhgrelland/hive:3.1.0 fredrikhgrelland/hive:latest

pem-to-p12:
	docker build ./pem-to-p12 -t fredrikhgrelland/pem-to-p12:latest
hue1:
	docker build ./hue -t zhenik/hue:20200526-135001
	docker tag  zhenik/hue:20200526-135001 zhenik/hue:latest
push:
	docker push fredrikhgrelland/hadoop:latest
	docker push fredrikhgrelland/hadoop:3.1.0
	docker push fredrikhgrelland/hive:latest
	docker push fredrikhgrelland/hive:3.1.0
	docker push fredrikhgrelland/pem-to-p12:latest
