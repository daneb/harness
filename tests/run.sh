#!/usr/bin/env bash
# Runs the regression suite. Plain shell, no framework, no network, no agents:
# adapters are exercised through stub binaries.
set -u
cd "$(dirname "$0")" || exit 1
source ./helpers.sh
source "$HARNESS_HOME/lib/common.sh"

# absolute paths: individual tests cd into their own scratch repos
source "$HROOT/tests/test-gates.sh"
source "$HROOT/tests/test-cli.sh"
source "$HROOT/tests/test-adapters.sh"

report
