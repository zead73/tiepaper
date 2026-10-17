#!/bin/sh
# Drives the real editor headlessly with scripted keystrokes and compares the
# resulting document text with tests/expected/.  Needs SDL2 and SDL2_ttf.
# Use "update" as the first argument to rewrite the expected files after
# checking the new output by hand.
cd "$(dirname "$0")/.."
mkdir -p build/test-out
rm -f build/test-out/*
rm -rf build/home; mkdir -p build/home
cp tests/fixtures/* build/test-out/
export HOME="$PWD/build/home" XDG_CONFIG_HOME="$PWD/build/home/.config" SDL_VIDEODRIVER=dummy
fail=0
have_spell=no
[ "$(echo teh | hunspell -l 2>/dev/null)" = teh ] && have_spell=yes
for s in tests/scripts/*.txt; do
  name=$(basename "$s" .txt)
  [ "$name" = spell ] && [ $have_spell = no ] && { echo "skipping spell test (no hunspell dictionary)"; continue; }

  rm -rf build/home; mkdir -p build/home      # every script starts with a clean configuration
  timeout 60 ./build/tiepaper --script "$s" || { echo "FAIL: $name did not run"; fail=1; }
done
if [ "$1" = update ]; then
  cp build/test-out/*.txt tests/expected/
  echo "expected files updated"
  exit 0
fi
# the saved files themselves
for f in sl_test.pcl sl_plain.txt; do
  [ -f "build/test-out/$f" ] || { echo "FAIL: $f was not written"; fail=1; }
done
if [ -f build/test-out/sl_test.pcl ] && ! head -c 40 build/test-out/sl_test.pcl | grep -q PAPERCLIP; then
  echo "FAIL: sl_test.pcl has no header line"; fail=1
fi
if [ -f build/test-out/sl_plain.txt ] && head -c 40 build/test-out/sl_plain.txt | grep -q PAPERCLIP; then
  echo "FAIL: sl_plain.txt should be plain text"; fail=1
fi
for f in tests/expected/*.txt; do
  n=$(basename "$f")
  [ "$n" = spell.txt ] && [ $have_spell = no ] && continue
  if ! diff -q "$f" "build/test-out/$n" >/dev/null 2>&1; then
    echo "FAIL: $n differs"; diff "$f" "build/test-out/$n" | head -10; fail=1
  fi
done
[ $fail = 0 ] && echo "gui tests passed"
exit $fail
