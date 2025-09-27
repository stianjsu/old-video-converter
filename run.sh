#!/bin/bash

echo "Building video converter Docker image..."
docker build -t video-converter .

echo "Starting video conversion..."
docker run --rm \
  -v "$(pwd)/input:/app/input" \
  -v "$(pwd)/output:/app/output" \
  video-converter

echo "Video conversion completed!"