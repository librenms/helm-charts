#!/bin/sh
TARGET="/data/env-volume/env"
echo "Target: $TARGET"
echo "APP_KEY=$(cat /data/key/appkey)" > $TARGET
echo "NODE_ID=$(hostname)" >> $TARGET

cat $TARGET
