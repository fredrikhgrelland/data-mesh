#!/bin/bash

function addProperty() {
  local path=$1
  local name=$2
  local value=$3

  local entry="<property><name>$name</name><value>${value}</value></property>"
  local escapedEntry=$(echo $entry | sed 's/\//\\\//g')
  sed -i "/<\/configuration>/ s/.*/${escapedEntry}\n&/" $path
}

function configure() {
    local path=$1
    local module=$2
    local envPrefix=$3

    local var
    local value
    
    echo "Configuring $module"
    for c in `printenv | perl -sne 'print "$1 " if m/^${envPrefix}_(.+?)=.*/' -- -envPrefix=$envPrefix`; do 
        name=`echo ${c} | perl -pe 's/___/-/g; s/__/_/g; s/_/./g'`
        var="${envPrefix}_${c}"
        value=${!var}
        echo " - Setting $name=$value"
        addProperty $path $name "$value"
    done
}

configure /etc/hadoop/core-site.xml core CORE_CONF
configure /etc/hadoop/hdfs-site.xml hdfs HDFS_CONF
configure /etc/hadoop/yarn-site.xml yarn YARN_CONF
configure /etc/hadoop/httpfs-site.xml httpfs HTTPFS_CONF
configure /etc/hadoop/kms-site.xml kms KMS_CONF
configure /etc/hadoop/mapred-site.xml mapred MAPRED_CONF
configure /opt/hive/conf/hive-site.xml hive HIVE_SITE_CONF
configure /opt/hive/conf/hivemetastore-site.xml hivemetastore HIVEMETASTORE_SITE_CONF
configure /opt/hive/conf/metastore-site.xml metastore METASTORE_SITE_CONF

echo "127.0.0.1 $(hostname)">/etc/hosts

tail -F /tmp/root/hive.log&

exec $@
