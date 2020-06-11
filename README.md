# data-mesh
A cloud native data mesh implementation 

## Introduction
This repo will set up a vagrant box on your local machine with an integrated suite of tools; `MinIO`, `hive`, `hive-metastore`, `Presto` and `Hue`. 

## How does this work
The stack is as mentioned in the introduction made up of `MinIO`, `hive` and `hive-metastore`, `Presto` and `Hue`. `MinIO` is the central place for storing our data. If you want something to be accessible to your SQL-interface it needs to be placed there. This data can then be accessed by `Presto` which takes SQL-code as input, and uses that as instructions for what and how it should retrieve the data that exists in `MinIO`. You could send scripts manually to `Presto`, but instead we have an integrated SQL-interface called `Hue` that is automatically connected to our `Presto`. In `Hue` you can then write SQL-queries that will automatically be executed by `Presto`.

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
To access the presto-dashboard open the URL [`http://localhost:8080`](http://localhost:8080) in your browser (NB: `make connection-to-presto` must be run first). Here you can see every query that has been executed by `Presto`, both failed and successful ones. You can also see general statistics of the `Presto` instance.


### Minio-dashboard
To access the minio-dashboard open the URL [http://localhost:8090](http://localhost:8090) in your browser (NB: `make connection-to-minio` must be run first). This dashboard shows all files you have stored, and they will be organised in what is called buckets. You can treat these as normal directories. There will already be two existing buckets, `hive` and `default`. To upload your own files you need to create a new bucket to put it in, which can be done by pressing the plus sign in the right hand corner, then the button looking like a hard drive, which is `create bucket` . You can now access your new bucket by clicking the name of your new bucket in the left hand column. To upload data to this bucket you click the plus-sign again, then the button that looks like a cloud. This will open a file-view window, where you can select what you want to upload. 


### Hue-dashboard
To access the hue-dashboard open the URL [http://localhost:8888](http://localhost:8888) in your browser (NB: `make connection-to-hue` must be run first). This is an interface where you can write and run sql queries that will be executed by our `Presto` instance. There is an example table already laying in our schema, and to query it you can run `SELECT * FROM iris`. 


### Presto-cli
If you want to use a local presto-cli and connect that directly to presto, instead of using a sql-interface like hue, you can do that by running these commands in sequence (NB: `make connection-to-presto` must be run first):
1. `make download-presto`
2. `make presto-cli`

There will now be a live-connection to presto in your terminal. Write `show tables;` in the terminal and hit enter. You will see there is one table available. This can be queried with `select * from iris;`.
