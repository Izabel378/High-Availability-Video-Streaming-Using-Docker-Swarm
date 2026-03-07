FROM alpine:latest

RUN apk add --no-cache bash jq yq docker-cli

WORKDIR /app

COPY swarm_watcher.sh .

RUN chmod +x swarm_watcher.sh

CMD ["bash", "/app/swarm_watcher.sh"]
