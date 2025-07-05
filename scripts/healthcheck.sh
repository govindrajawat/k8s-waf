#!/bin/bash
set -e

if curl -sf http://localhost:8080/health; then
  exit 0
else
  exit 1
fi 