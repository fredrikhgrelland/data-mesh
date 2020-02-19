FROM openjdk:8-jre-alpine3.9
MAINTAINER "Fredrik Hoem Grelland"
COPY --from=hashicorp/consul-template:scratch "/consul-template" "/bin/consul-template"
RUN apk add --no-cache openssl
ENTRYPOINT ["/bin/consul-template"]

