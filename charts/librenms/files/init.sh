#!/bin/sh
# Generate stable NODE_ID from hostname for distributed polling
TARGET="/data/env-volume/env"
echo "Generating NODE_ID from hostname: $(hostname)"
echo "NODE_ID=$(hostname)" > $TARGET
cat $TARGET
