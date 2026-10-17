#!/bin/bash
# Runs INSIDE the build container (see Dockerfile): compiles TiePaper, assembles the AppDir
# with the SDL2 libraries it loads at run time, and packs dist/tiepaper-x86_64.AppImage.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
APPDIR=build/appimage/TiePaper.AppDir
LIBDIR=$APPDIR/usr/lib
OUT=dist/tiepaper-x86_64.AppImage

mkdir -p build/units-appimage build/appimage dist
fpc -Mobjfpc -Sh -O2 -Xs -FUbuild/units-appimage -Fusrc -FEbuild/appimage -otiepaper src/tiepaper.lpr
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$LIBDIR" "$APPDIR/usr/share/doc/tiepaper" "$APPDIR/usr/share/tiepaper"
cp build/appimage/tiepaper "$APPDIR/usr/bin/tiepaper"
cp -r fonts "$APPDIR/usr/fonts"
cp -r examples "$APPDIR/usr/share/tiepaper/examples"
cp LICENSE "$APPDIR/usr/share/doc/tiepaper/LICENSE"

# TiePaper opens SDL2 and SDL2_ttf with dlopen, so they never show up in its own ldd.  The
# two libraries built in the container need nothing but glibc (checked below), which comes
# from the host; X11 / Wayland / OpenGL are opened by SDL itself from the host as well.
cp -a /opt/sdl/lib/libSDL2-2.0.so.0* /opt/sdl/lib/libSDL2_ttf-2.0.so.0* "$LIBDIR/"
for lib in "$LIBDIR"/*.so.0; do
  extra=$(readelf -d "$lib" | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p' | grep -vE '^(libc|libm|libdl|libpthread|librt)\.so|^libSDL2-2\.0\.so\.0$' || true)
  [ -z "$extra" ] || { echo "$lib needs more than glibc: $extra" >&2; exit 1; }
done
# licence texts (FreeType's asks for its credit to travel with it)
mkdir -p "$APPDIR/usr/share/doc/tiepaper/licenses"
cp assets/licenses/SDL2-LICENSE.txt assets/licenses/SDL2_ttf-LICENSE.txt assets/licenses/FreeType-FTL.txt \
  "$APPDIR/usr/share/doc/tiepaper/licenses/"

install -m 755 packaging/appimage/AppRun "$APPDIR/AppRun"
install -m 644 packaging/appimage/tiepaper.desktop "$APPDIR/tiepaper.desktop"
install -m 644 assets/png/tiepaper-256.png "$APPDIR/tiepaper.png"
ln -s tiepaper.png "$APPDIR/.DirIcon"
chmod +x "$APPDIR/usr/bin/tiepaper"

ARCH=x86_64 appimagetool "$APPDIR" "$OUT"

echo; echo "bundled libraries:"; ls -1 "$LIBDIR"
echo "glibc floor: $(objdump -T "$APPDIR"/usr/bin/tiepaper "$LIBDIR"/*.so* 2>/dev/null \
  | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1)"
echo "built $OUT"
