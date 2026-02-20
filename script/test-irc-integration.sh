#!/usr/bin/env bash

# Integration test script for Convos IRC backend.
# Runs TestIRCIntegration against a live IRC server (e.g. ergochat).

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <irc-server-url>"
  echo ""
  echo "Examples:"
  echo "  $0 'irc://localhost:6667?tls=0'   # plain-text local ergochat"
  echo "  $0 'irc://localhost:6697'          # TLS with insecure cert verify"
  echo ""
  echo "The URL is passed via CONVOS_TEST_IRC_SERVER."
  echo "Run an ergochat instance locally before executing this script."
  exit 1
fi

IRC_SERVER="$1"
echo "Running IRC integration tests against: $IRC_SERVER"
echo ""

CONVOS_TEST_IRC_SERVER="$IRC_SERVER" go test -v -run TestIRCIntegration -timeout 120s ./pkg/irc/
