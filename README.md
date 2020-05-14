# data-mesh
A cloud native data mesh implementation 

## Setup
This dev environment implementation of the datamesh will set up and start all services on your local computer.
It currently requires a 64bin linux host with sudo because nomad will set up local network using CSI in order to secure the mesh communication.

1. Download binaries and build docker images
`make download docker`
2. 
