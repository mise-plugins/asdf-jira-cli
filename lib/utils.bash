#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/ankitpokhrel/jira-cli"
TOOL_NAME="jira"
TOOL_TEST="jira version"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if jira-cli is not hosted on GitHub releases.
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
	list_github_tags
}

download_release() {
	local version filename url
	version="$1"
	filename="$2"

	# we must get the os/architecture.
	ARCH=$(uname -m)
	OS=$(uname -s | awk '{print tolower($0)}')

	if [ "$OS" == "darwin" ]; then
		OS="macOS"
	fi
	if [ "$ARCH" == "aarch64" ]; then
		ARCH="arm64"
	fi

	RELEASE_FILE="jira_${version}_${OS}_${ARCH}.tar.gz"

	url="$GH_REPO/releases/download/v${version}/${RELEASE_FILE}"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"

	if which sha256sum &>/dev/null; then
		echo -n "* Checking checksum..."
		if curl -sL "$GH_REPO/releases/download/v${version}/checksums.txt" | awk -v filename="$filename" -v release_file="$RELEASE_FILE" '$0 ~ release_file { print $1" "filename }' | sha256sum -c --quiet; then
			echo "OK"
		else
			echo "ERR: checksum did not match...  Quitting"
			exit 1
		fi
	else
		echo "* Skipping checksum validation... sha256sum not found in path"
	fi
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
