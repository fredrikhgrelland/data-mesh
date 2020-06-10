# data-mesh
A cloud native data mesh implementation 

## Introduction
This repo will set up a vagrant box on your local machine that contains a fully featured suite of tools, including `minio`, `hive` and `hive-metastore`, `presto` and `hue`. 

## How to use
### Setup
1. From the same folder that contains this `README`, run `make up`. 
This will start the process of provisioning a vagrant box on your machine. Everything is automated, and it will set up the components mentioned in the introduction.

After everything is set up you need to establish connections to the components inside your vagrant box. There are four commands, and they will all need their own terminal-window as long as you want the connection to stay open. You can choose what components you want to open a connection to. If you don't need to go into the presto-dashboard, you don't have to open a connection.
1. `make connection-to-minio`
2. `make connection-to-hive`
3. `make connection-to-presto`
4. `make connection-to-hue`

After running the commands above, the URL to access their respective components are:
1. MinIO: `localhost:8090`
2. Hive: `localhost:8070`
3. Presto: `localhost:8080`
4. Hue: `localhost:8888`


### Presto-dashboard
TODO, quick intro to the presto-dashbaord


### Minio-dashboard
TODO, quick intro to the minio-dashboard


### Hue-dashboard
TODO, quick intro to the hue-dashboard


### Presto-cli
If you want to use a local presto-cli and connect that directly to presto, instead of using a sql-interface like hue, you can do that by running these commands in sequence:
1. `make download-presto`
2. `make presto-cli`

There will now be a live-connection to presto in your terminal. Write `show tables;` in the terminal and hit enter. You will see there is one table available. This can be queried with `select * from iris;`.
