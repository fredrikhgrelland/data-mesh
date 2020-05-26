`"recursors" : ["151.187.151.101"],` hva er denne IP'en?

`  "addresses" : {
    "http" : "127.0.0.1 {{ GetInterfaceIP \"docker0\" }}",
    "dns" : "127.0.0.1 {{ GetInterfaceIP \"docker0\" }}",
    "grpc" : "127.0.0.1 {{ GetInterfaceIP \"docker0\" }}"
  }
` hvorfor settes alle disse til lokal OG docker sine egne IPer?


`sudo ./bin/nomad agent -dev-connect -consul-token=${CONSUL_MASTER_TOKEN} -bind=${HOST_DOCKER} -network-interface=${NETWORK_INTERFACE} -consul-address=127.0.0.1:8500
` hva eksakt vil det si at connect blir tilgjengeliggjort på public i stedet for local når nomad agent blir kjørt med -dev-connect? [Referanse](https://www.nomadproject.io/docs/commands/agent/#dev-connect)

Hvorfor adresser som gjelder internal communication bundet til ${DOCKER_HOST} når alle docker-servicer er tilgjengelig på localhost? Eksempel: 
`sudo ./bin/nomad agent -dev-connect -consul-token=${CONSUL_MASTER_TOKEN} -bind=${HOST_DOCKER} -network-interface=${NETWORK_INTERFACE} -consul-address=127.0.0.1:8500
` consul address er localhost, mens bind_addr ikke er det. 

Hva gjør egentlig certficate handler? Skjønner at den håndterer sertifikater, men hvordan funker det med consul. 
```
task "certificate-handler" {
  driver = "docker"
  config {
    image = "certificate-handler:1"
    entrypoint = ["/bin/sh"]
    args = [
      "-c", "openssl pkcs12 -export -password pass:changeit -in /local/leaf.pem -inkey /local/leaf.key -certfile /local/leaf.pem -out /local/presto.p12; keytool -noprompt -importkeystore -srckeystore /local/presto.p12 -srcstoretype pkcs12 -destkeystore /local/presto.jks -deststoretype JKS -deststorepass changeit -srcstorepass changeit; keytool -noprompt -import -trustcacerts -keystore /local/presto.jks -storepass changeit -alias Root -file /local/roots.pem; keytool -noprompt -importkeystore -srckeystore /local/presto.jks -destkeystore /alloc/presto.jks -deststoretype pkcs12 -deststorepass changeit -srcstorepass changeit; tail -f /dev/null"
    ]
  }
```

`curl -s -H X-Consul-Token:${CONSUL_MASTER_TOKEN} -X PUT -d "{ \"Name\": \"presto\", \"Service\": \"presto\", \"Port\": $${PRESTO_PORT}, \"Address\": \"$${PRESTO_IP}\", \"connect\": { \"native\": true } }" http://127.0.0.1:8500/v1/agent/service/register?replace-existing-checks=true
`, Ikke heeeelt sikker på denne, spør om jeg ikke finner ut senere.

```
build-certificate-handler:
	docker build . -t certificate-handler:v0.1
```
Hvor er dockerfilen?

Hvorfor dukker nomad opp på 127.17.0.1 og ikke 127.0.0.1, når consul dukker opp på localhost (127.0.0.1)?