#!/bin/bash

set -e

mkdir -p output

if [ "${KEEP_OUTPUT:-0}" != "1" ]; then
  echo "Clearing output directory..."
  rm -rf output/*
fi

echo "Building video converter Docker image..."
docker build -t video-converter .

echo "Starting video conversion..."
docker run --rm \
  -v "$(pwd)/input:/app/input" \
  -v "$(pwd)/output:/app/output" \
  video-converter python3 convert.py

echo "Video conversion completed!"
