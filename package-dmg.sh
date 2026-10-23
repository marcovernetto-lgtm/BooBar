#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
architecture="${1:-universal}"
zsh build-app.sh "$architecture"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
stage="$(mktemp -d "$PWD/.build/dmg.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
/usr/bin/ditto .build/BooBar.app "$stage/BooBar.app"
ln -s /Applications "$stage/Applications"
touch "$stage/.metadata_never_index"
mkdir -p dist
image="$PWD/dist/BooBar-$version-$architecture.dmg"
/usr/bin/hdiutil create -volname "BooBar" -srcfolder "$stage" -fs HFS+ -format UDZO -ov "$image"
/usr/bin/hdiutil verify "$image"
(cd dist && /usr/bin/shasum -a 256 "${image:t}" > "${image:t}.sha256")
print "$image"
