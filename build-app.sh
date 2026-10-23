#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
architecture="${1:-universal}"
case "$architecture" in
    arm64|x86_64) architectures=("$architecture") ;;
    universal) architectures=(arm64 x86_64) ;;
    *) print -u2 'Usage: zsh build-app.sh [universal|arm64|x86_64]'; exit 1 ;;
esac
mkdir -p .tmp .cache
export TMPDIR="$PWD/.tmp"
export SWIFT_MODULE_CACHE_PATH="$PWD/.cache/boobar-swift"
export CLANG_MODULE_CACHE_PATH="$PWD/.cache/boobar-clang"
binaries=()
for target_arch in "${architectures[@]}"; do
    build_args=(--scratch-path ".build/boobar-$target_arch" -c release --arch "$target_arch" -Xswiftc -Osize -Xlinker -dead_strip)
    swift build "${build_args[@]}"
    binary_dir="$(swift build "${build_args[@]}" --show-bin-path)"
    binaries+=("$binary_dir/BooBar")
done
app="$PWD/.build/BooBar.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
/usr/bin/lipo -create "${binaries[@]}" -output "$app/Contents/MacOS/BooBar"
/usr/bin/strip -x "$app/Contents/MacOS/BooBar"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/BooBar.icns "$app/Contents/Resources/"
if [[ -n "${BOOBAR_SIGN_IDENTITY:-}" ]]; then
    /usr/bin/codesign --force --options runtime --timestamp --sign "$BOOBAR_SIGN_IDENTITY" "$app"
    /usr/bin/codesign --verify --strict "$app"
else
    python3 Tools/sign.py "$app"
fi
/usr/bin/lipo -archs "$app/Contents/MacOS/BooBar"
print "$app"
