#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/errata-ai/vale"
TOOL_NAME="vale"
TOOL_TEST="vale --version"

fail() {
	echo -e "asdf-$TOOL_NAME: $*" > /dev/stderr
	exit 1
}

get_os() {
	os=$(uname -s)
	case $os in
	Darwin) os="macOS" ;;
	Linux) os="Linux" ;;
	*) fail "The os (${os}) is not supported by this installation script." ;;
	esac
	echo "$os"
}

get_arch() {
	arch=$(uname -m)
	case $arch in
	x86_64) arch="64-bit" ;;
	arm64) arch="arm64" ;;
 	aarch64) arch="arm64" ;;
	*) fail "The architecture (${arch}) is not supported by this installation script." ;;
	esac
	echo "$arch"
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if vale is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
	# Change this function if vale has other means of determining installable versions.
	list_github_tags
}

download_release() {
	local version filename url
	version="$1"
	filename="$2"

	arch=$(get_arch)
	os=$(get_os)
	url="$GH_REPO/releases/download/v${version}/vale_${version}_${os}_${arch}.tar.gz"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"

		mkdir -p "$install_path"
		cp -r "$ASDF_DOWNLOAD_PATH/${tool_cmd}" "$install_path/$tool_cmd"

		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
