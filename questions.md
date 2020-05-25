`"recursors" : ["151.187.151.101"],` hva er denne IP'en?

`  "addresses" : {
    "http" : "127.0.0.1 {{ GetInterfaceIP \"docker0\" }}",
    "dns" : "127.0.0.1 {{ GetInterfaceIP \"docker0\" }}",
    "grpc" : "127.0.0.1 {{ GetInterfaceIP \"docker0\" }}"
  }
` hvorfor settes alle disse til lokal OG docker sine egne IPer?


`sudo ./bin/nomad agent -dev-connect -consul-token=${CONSUL_MASTER_TOKEN} -bind=${HOST_DOCKER} -network-interface=${NETWORK_INTERFACE} -consul-address=127.0.0.1:8500
` hva eksakt vil det si at connect blir tilgjengeliggjort på public i stedet for local når nomad agent blir kjørt med -dev-connect? [Referanse](https://www.nomadproject.io/docs/commands/agent/#dev-connect)