# Build environment for the TiePaper AppImage: Debian 12 (glibc 2.36), so the result runs
# on Debian 12 / Ubuntu 22.04 and anything newer.  Provides fpc 3.2.2, the real SDL2 and
# SDL2_ttf libraries to bundle (not sdl2-compat) and a pinned appimagetool.
FROM debian:12

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
         fpc binutils gcc libc6-dev libsdl2-2.0-0 libsdl2-ttf-2.0-0 curl ca-certificates file \
    && rm -rf /var/lib/apt/lists/*

# appimagetool 1.9.1 (static ELF, so no FUSE is needed to package), checked against the
# digest GitHub publishes for that release asset
ARG APPIMAGETOOL_SHA=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0
RUN curl -fL -o /usr/local/bin/appimagetool \
      https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage \
    && echo "$APPIMAGETOOL_SHA  /usr/local/bin/appimagetool" | sha256sum -c - \
    && chmod +x /usr/local/bin/appimagetool

# appimagetool is itself an AppImage and a container has no FUSE: self-extract and run
ENV APPIMAGE_EXTRACT_AND_RUN=1

WORKDIR /src
ENTRYPOINT ["packaging/appimage/build.sh"]
