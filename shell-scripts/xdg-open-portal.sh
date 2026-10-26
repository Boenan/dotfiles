#!/bin/sh
# xdg-open for the distrobox container. The browser is on the host, so ask
# the host's xdg-desktop-portal, over the shared D-Bus session bus, to open
# the file or URL with its default application.
set -eu
target=${1:?usage: xdg-open FILE|URL}
portal() {
    busctl --user call org.freedesktop.portal.Desktop \
        /org/freedesktop/portal/desktop org.freedesktop.portal.OpenURI "$@" \
        >/dev/null
}
case $target in
    file://*)
        path=$(python3 -I -c 'import sys, urllib.parse
print(urllib.parse.unquote(urllib.parse.urlsplit(sys.argv[1]).path))' "$target") ;;
    *:*)
        portal OpenURI 'ssa{sv}' '' "$target" 0
        exit ;;
    *)
        path=$target ;;
esac
# OpenFile takes an open file descriptor, not a path.
portal OpenFile 'sha{sv}' '' 3 0 3<"$path"
