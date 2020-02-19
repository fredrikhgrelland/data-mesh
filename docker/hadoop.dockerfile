FROM openjdk:8-alpine
ENV HADOOP_VERSION 3.1.0

COPY  CUSTOM_CA.crt /usr/local/share/ca-certificates/

RUN apk add --no-cache ca-certificates procps curl tar bash perl \
    && update-ca-certificates 2>/dev/null || true \
    && rm -rf /var/cache/apk/*

RUN curl -s -L https://archive.apache.org/dist/hadoop/core/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz | tar xz -C /opt/

RUN ln -s /opt/hadoop-$HADOOP_VERSION/etc/hadoop /etc/hadoop
RUN mkdir /opt/hadoop-$HADOOP_VERSION/logs

ENV HADOOP_HOME=/opt/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV USER=root
ENV PATH $HADOOP_HOME/bin/:$PATH