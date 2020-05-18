## Note on versions
Compatiability of hadoop and hive is ensured by using A know working combination.
See Hortonworks ( or cloudera ) compatibility in releasenotes. https://docs.cloudera.com/HDPDocuments/HDP3/HDP-3.1.0/release-notes/content/comp_versions.html


beeline -u "jdbc:hive2://localhost:10000/default;auth=noSasl" -n hive -p hive
