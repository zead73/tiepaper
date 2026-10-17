#!/bin/sh
# Builds the Linux version into build/tiepaper
set -e
cd "$(dirname "$0")"
mkdir -p build/units
fpc -Mobjfpc -Sh -O2 -Xs -FUbuild/units -Fusrc -FEbuild -otiepaper src/tiepaper.lpr
echo "Built: build/tiepaper"
