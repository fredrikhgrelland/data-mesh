#FROM fredrikhgrelland/atlas:latest as atlas
FROM fredrikhgrelland/hadoop:latest

# Allow buildtime config of HIVE_VERSION
ARG HIVE_VERSION
# Set HIVE_VERSION from arg if provided at build, env if provided at run, or default
ENV HIVE_VERSION=${HIVE_VERSION:-3.1.0}
ENV HIVE_DOWNLOAD https://archive.apache.org/dist/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz
ENV HIVE_HOME /opt/hive
ENV POSTGRES_JDBC_VERSION 42.2.12
ENV PATH $HIVE_HOME/bin:$PATH

#Add ca_certificates to the image ( if trust is not allready added through base image )
COPY ca_certificates/* /usr/local/share/ca-certificates/
COPY . /var/tmp/
WORKDIR /var/tmp

#COPY --from=atlas /opt/atlas/hooks/apache-atlas-2.0.0-hive-hook.tar.gz /tmp

#Install Hive and PostgreSQL JDBC
RUN \
    #Update CA_Certs
    update-ca-certificates 2>/dev/null || true && echo "NOTE: CA warnings suppressed." \
    #Test download ( does ssl trust work )
    && curl -s -I -o /dev/null $HIVE_DOWNLOAD || echo -e "\n###############\nERROR: You are probably behind a corporate proxy. Add your custom ca .crt in the ca_certificates docker build folder\n###############\n" \
    #Download and unpack hive
    && curl -s -L $HIVE_DOWNLOAD | tar -xz --transform s/apache-hive-$HIVE_VERSION-bin/hive/ -C /opt/ \
    #Download postgres jdbc driver
    && curl -s -L https://jdbc.postgresql.org/download/postgresql-$POSTGRES_JDBC_VERSION.jar -o $HIVE_HOME/lib/postgresql-jdbc.jar \
    && mkdir -p $HIVE_HOME/extlib \
    #Install Atlas hooks
    #&& tar xf /tmp/apache-atlas-2.0.0-hive-hook.tar.gz --strip-components 1 -C $HIVE_HOME/extlib \
    ; for file in $(find $HIVE_HOME/extlib/ -name '*.jar' -print); do ln -s $file $HIVE_HOME/lib/; done;\
	#Install AWS s3 drivers
	ln -s $HADOOP_HOME/share/hadoop/tools/lib/aws-java-sdk-bundle-*.jar $HIVE_HOME/lib/. \
	&& ln -s $HADOOP_HOME/share/hadoop/tools/lib/hadoop-aws-$HADOOP_VERSION.jar $HIVE_HOME/lib/. \
	&& ln -s $HADOOP_HOME/share/hadoop/tools/lib/aws-java-sdk-bundle-*.jar $HADOOP_HOME/share/hadoop/common/lib/. \
	&& ln -s $HADOOP_HOME/share/hadoop/tools/lib/hadoop-aws-$HADOOP_VERSION.jar $HADOOP_HOME/share/hadoop/common/lib/. \
	#Remove libs causing error from hive - duplicated from hadoop
	&& rm /opt/hive/lib/log4j-slf4j-impl-*.jar \
    && mv /var/tmp/conf/* $HIVE_HOME/conf/ \
	&& mv /var/tmp/startup.sh /var/tmp/entrypoint.sh /usr/local/bin/ \
    && chmod +x /usr/local/bin/startup.sh /usr/local/bin/entrypoint.sh

EXPOSE 10000
EXPOSE 10002
EXPOSE 9083

WORKDIR /opt
ENTRYPOINT ["entrypoint.sh"]
CMD startup.sh