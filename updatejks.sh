#!/bin/bash -eux
rm -f *.jks* *.pem *.p12 *.key|| true

curl -s -H X-Consul-Token:b6e29626-e23d-98b4-e19f-c71a96fbdef7 http://172.17.0.1:8500/v1/agent/connect/ca/leaf/presto | jq -r .CertPEM > presto.pem
curl -s -H X-Consul-Token:b6e29626-e23d-98b4-e19f-c71a96fbdef7 http://172.17.0.1:8500/v1/agent/connect/ca/leaf/presto | jq -r .PrivateKeyPEM > presto.key
curl -s -H X-Consul-Token:b6e29626-e23d-98b4-e19f-c71a96fbdef7 http://172.17.0.1:8500/v1/agent/connect/ca/leaf/presto-worker | jq -r .CertPEM > presto-worker.pem
curl -s -H X-Consul-Token:b6e29626-e23d-98b4-e19f-c71a96fbdef7 http://172.17.0.1:8500/v1/agent/connect/ca/leaf/presto-worker | jq -r .PrivateKeyPEM > presto-worker.key
curl -s -H X-Consul-Token:b6e29626-e23d-98b4-e19f-c71a96fbdef7 http://172.17.0.1:8500/v1/agent/connect/ca/leaf/test | jq -r .CertPEM > test.pem
curl -s -H X-Consul-Token:b6e29626-e23d-98b4-e19f-c71a96fbdef7 http://172.17.0.1:8500/v1/agent/connect/ca/leaf/test | jq -r .PrivateKeyPEM > test.key
curl -s -H X-Consul-Token:b6e29626-e23d-98b4-e19f-c71a96fbdef7 http://172.17.0.1:8500/v1/agent/connect/ca/roots | jq -r .Roots[].RootCert > roots.pem

echo "creating p12..."
openssl pkcs12 -export -password pass:changeit -in presto.pem -inkey presto.key -certfile presto.pem -out presto.p12
openssl pkcs12 -export -password pass:changeit -in presto-worker.pem -inkey presto-worker.key -certfile presto-worker.pem -out presto-worker.p12
openssl pkcs12 -export -password pass:changeit -in test.pem -inkey test.key -certfile test.pem -out test.p12

echo "importing p12 into jks..."
keytool -noprompt -importkeystore -srckeystore presto.p12 -srcstoretype pkcs12 -destkeystore presto.jks -deststoretype JKS -deststorepass changeit -srcstorepass changeit
keytool -noprompt -importkeystore -srckeystore presto-worker.p12 -srcstoretype pkcs12 -destkeystore presto-worker.jks -deststoretype JKS -deststorepass changeit -srcstorepass changeit
keytool -noprompt -importkeystore -srckeystore test.p12 -srcstoretype pkcs12 -destkeystore test.jks -deststoretype JKS -deststorepass changeit -srcstorepass changeit

echo "adding root to jks..."
keytool -noprompt -import -trustcacerts -keystore presto.jks -noprompt -storepass changeit -alias Root -file roots.pem
keytool -noprompt -import -trustcacerts -keystore presto-worker.jks -noprompt -storepass changeit -alias Root -file roots.pem
keytool -noprompt -import -trustcacerts -keystore test.jks -noprompt -storepass changeit -alias Root -file roots.pem

echo "jks to pkcs12 format..."
keytool -noprompt -importkeystore -srckeystore presto.jks -destkeystore presto.jks -deststoretype pkcs12 -deststorepass changeit -srcstorepass changeit
keytool -noprompt -importkeystore -srckeystore presto-worker.jks -destkeystore presto-worker.jks -deststoretype pkcs12 -deststorepass changeit -srcstorepass changeit
keytool -noprompt -importkeystore -srckeystore test.jks -destkeystore test.jks -deststoretype pkcs12 -deststorepass changeit -srcstorepass changeit

echo "creating bundle..."
cat presto.pem roots.pem > presto-bundle.pem
cat presto-worker.pem roots.pem > presto-worker-bundle.pem
cat test.pem roots.pem > test-bundle.pem

