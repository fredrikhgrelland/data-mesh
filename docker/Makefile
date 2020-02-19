branch := $( shell git rev-parse --abbrev-ref HEAD)

.ONESHELL .PHONY: hadoop hive pem-to-p12 all build push
.DEFAULT_GOAL := build

all: build push

build: hadoop hive pem-to-p12

hadoop:
	docker build ./hadoop -t fredrikhgrelland/hadoop:latest

hive:
	docker build ./hive -t fredrikhgrelland/hive:latest

pem-to-p12:
	docker build ./pem-to-p12 -t fredrikhgrelland/pem-to-p12:latest

push:
	docker push fredrikhgrelland/hadoop:latest
	docker push fredrikhgrelland/hive:latest
	docker push fredrikhgrelland/pem-to-p12:latest
