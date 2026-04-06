# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Batch converter for early-2000s camera footage (.mpg/.mpeg etc.) to .mp4 for modern playback compatibility and storage efficiency.

## Architecture

`run.sh` builds and runs a Docker container that executes `convert.sh`, which uses ffmpeg/ffprobe to re-encode all input files.
