branch := $( shell git rev-parse --abbrev-ref HEAD)

.ONESHELL .PHONY: build pem-to-p12 hue1
.DEFAULT_GOAL := build

build: pem-to-p12 hue1

custom_ca:
ifdef CUSTOM_CA
	cp -rf $(CUSTOM_CA)/* ./hadoop/ca_certificates/ || cp -f $(CUSTOM_CA) ./hadoop/ca_certificates/
endif

pem-to-p12:
	docker build ./pem-to-p12 -t fredrikhgrelland/pem-to-p12:latest

hue1: custom_ca
	docker build ./hue -t zhenik/hue:20200526-135001
	docker tag  zhenik/hue:20200526-135001 zhenik/hue:latest
