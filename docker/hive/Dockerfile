#FROM fredrikhgrelland/atlas:latest as atlas
FROM fredrikhgrelland/hadoop:latest

# Allow buildtime config of HIVE_VERSION
ARG HIVE_VERSION
# Set HIVE_VERSION from arg if provided at build, env if provided at run, or default
# https://docs.docker.com/engine/reference/builder/#using-arg-variables
# https://docs.docker.com/engine/reference/builder/#environment-replacement
ENV HIVE_VERSION=${HIVE_VERSION:-3.1.0}

ENV HIVE_HOME /opt/hive
ENV PATH $HIVE_HOME/bin:$PATH

WORKDIR /opt
#COPY --from=atlas /opt/atlas/hooks/apache-atlas-2.0.0-hive-hook.tar.gz /tmp

#Install Hive and PostgreSQL JDBC
RUN \
	curl -L https://archive.apache.org/dist/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz | tar xz && mv apache-hive-$HIVE_VERSION-bin hive && \
    curl https://jdbc.postgresql.org/download/postgresql-42.2.8.jar -o $HIVE_HOME/lib/postgresql-jdbc.jar \
    && mkdir $HIVE_HOME/extlib \
    #Install Atlas hooks
    #&& tar xf /tmp/apache-atlas-2.0.0-hive-hook.tar.gz --strip-components 1 -C $HIVE_HOME/extlib \
	&& for file in $(find $HIVE_HOME/extlib/ -name '*.jar' -print); do ln -s $file $HIVE_HOME/lib/; done;\
	#Install AWS s3 drivers
	&& ln -s $HADOOP_HOME/share/hadoop/tools/lib/aws-java-sdk-bundle-*.jar $HIVE_HOME/lib/. \
	&& ln -s $HADOOP_HOME/share/hadoop/tools/lib/hadoop-aws-$HADOOP_VERSION.jar $HIVE_HOME/lib/. \
	&& ln -s $HADOOP_HOME/share/hadoop/tools/lib/aws-java-sdk-bundle-*.jar $HADOOP_HOME/share/hadoop/common/lib/. \
	&& ln -s $HADOOP_HOME/share/hadoop/tools/lib/hadoop-aws-$HADOOP_VERSION.jar $HADOOP_HOME/share/hadoop/common/lib/. \
	&& rm /opt/hive/lib/log4j-slf4j-impl-*.jar

#Custom configuration goes here
COPY hive-site.xml $HIVE_HOME/conf
COPY hivemetastore-site.xml $HIVE_HOME/conf
COPY metastore-site.xml $HIVE_HOME/conf
COPY beeline-log4j2.properties $HIVE_HOME/conf
COPY hive-env.sh $HIVE_HOME/conf
COPY hive-exec-log4j2.properties $HIVE_HOME/conf
COPY hive-log4j2.properties $HIVE_HOME/conf
COPY ivysettings.xml $HIVE_HOME/conf
COPY llap-daemon-log4j2.properties $HIVE_HOME/conf

COPY startup.sh /usr/local/bin/
COPY hive-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/startup.sh /usr/local/bin/entrypoint.sh

EXPOSE 10000
EXPOSE 10002
EXPOSE 9083

ENTRYPOINT ["entrypoint.sh"]
CMD startup.sh