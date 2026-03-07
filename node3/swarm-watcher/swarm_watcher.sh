#!/bin/bash

DICT=/config/dict.yaml

echo "Starting swarm monitor..."
echo ""

docker events --filter type=node --format '{{json .}}' |
while read -r event
do
    docker node ls --format '{{.Hostname}} {{.Status}}' |
    while read NODE STATUS
    do
        if [ "$STATUS" = "Down" ]; then
            VALUE=$(yq e ".${NODE}" "$DICT")

            [ "$VALUE" = "null" ] && VALUE="Unknown node"

            echo "$(date '+%H:%M:%S')  ALERT $NODE is DOWN"
            echo "$(date '+%H:%M:%S')  Identity -> $VALUE"
            echo ""
        fi
    done
done
