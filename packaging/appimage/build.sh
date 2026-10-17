#!/bin/bash
# Runs INSIDE the build container (see Dockerfile): compiles TiePaper, assembles the AppDir
# with the SDL2 libraries it loads at run time, and packs dist/tiepaper-x86_64.AppImage.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
APPDIR=build/appimage/TiePaper.AppDir
LIBDIR=$APPDIR/usr/lib
OUT=dist/tiepaper-x86_64.AppImage

mkdir -p build/units-appimage dist
fpc -Mobjfpc -Sh -O2 -Xs -FUbuild/units-appimage -Fusrc -FEbuild/appimage -otiepaper src/tiepaper.lpr
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$LIBDIR" "$APPDIR/usr/share/doc/tiepaper" "$APPDIR/usr/share/tiepaper"
cp build/appimage/tiepaper "$APPDIR/usr/bin/tiepaper"
cp -r fonts "$APPDIR/usr/fonts"
cp -r examples "$APPDIR/usr/share/tiepaper/examples"
cp LICENSE "$APPDIR/usr/share/doc/tiepaper/LICENSE"

# TiePaper opens SDL2 and SDL2_ttf with dlopen, so they never show up in its own ldd:
# take the two libraries and everything they need, except what must come from the host
# (glibc, the graphics stack, the X11 / Wayland client libraries SDL loads itself, and the
# C++ runtime, which an old bundled copy could break for the host's Mesa).
host_lib() {
  case "$1" in
    libc.so.*|libm.so.*|libdl.so.*|libpthread.so.*|librt.so.*|libresolv.so.*|ld-linux*|linux-vdso*) return 0 ;;
    libGL*|libEGL*|libGLX*|libGLES*|libOpenGL*|libvulkan*|libgbm*|libdrm*|libX*|libxcb*|libwayland*) return 0 ;;
    libstdc++.so.*|libgcc_s.so.*|libasound*|libpulse*|libpipewire*|libudev*|libdbus*|libsystemd*) return 0 ;;
  esac
  return 1
}
find_lib() { ldconfig -p | awk -v n="$1" '$1==n {print $NF; exit}'; }
deps() { ldd "$1" | awk '/=>/ {print $3}'; }
for name in libSDL2-2.0.so.0 libSDL2_ttf-2.0.so.0; do
  path=$(find_lib $name)
  [ -n "$path" ] || { echo "$name not found in the build container" >&2; exit 1; }
  for lib in "$path" $(deps "$path"); do
    base=$(basename "$lib")
    host_lib "$base" && continue
    [ -e "$LIBDIR/$base" ] || cp -L "$lib" "$LIBDIR/$base"
  done
done

# licence texts of everything bundled (FreeType's asks for its credit to travel with it)
for lib in "$LIBDIR"/*; do
  pkg=$(dpkg -S "$(readlink -f "$lib")" 2>/dev/null | head -1 | cut -d: -f1)
  [ -n "$pkg" ] || continue
  mkdir -p "$APPDIR/usr/share/doc/$pkg"
  cp -L "/usr/share/doc/$pkg/copyright" "$APPDIR/usr/share/doc/$pkg/copyright" 2>/dev/null || true
done

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
