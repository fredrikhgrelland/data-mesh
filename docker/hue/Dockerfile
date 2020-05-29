FROM gethue/hue:20200526-135001

ARG PRESTO_VERSION
ENV PRESTO_VERSION=${PRESTO_VERSION:-333}

#Add ca_certificates to the image ( if trust is not allready added through base image )
COPY ca_certificates/* /usr/local/share/ca-certificates/

RUN \
    #Update CA_Certs
    update-ca-certificates 2>/dev/null || true && echo "NOTE: CA warnings suppressed."

# Install Presto JDBC driver
RUN mkdir -p /opt/presto
RUN curl -L https://repo1.maven.org/maven2/io/prestosql/presto-jdbc/${PRESTO_VERSION}/presto-jdbc-${PRESTO_VERSION}.jar \
         -o /opt/presto/presto-jdbc.jar

# Install presto connector
# https://docs.gethue.com/administrator/configuration/connectors/#presto
RUN ./build/env/bin/pip install pyhive

#leave original config
#COPY conf desktop/conf
COPY startup.sh .
RUN chmod +x startup.sh

EXPOSE 8888
CMD ["./startup.sh"]


