#!/bin/bash

# build and run the production Docker Compose setup for the Transit Auto-Unsealer client

docker-compose -f docker-compose-client.yml build app

# docker-compose -f docker-compose-client.yml up -d app
docker-compose -f docker-compose-client.yml up app # run in foreground to see logs