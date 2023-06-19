#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

GH_REPO="https://github.com/Wilfred/difftastic"
TOOL_NAME="difftastic"
TOOL_TEST="difftastic --help"

fail() {
	echo -e "asdf-${TOOL_NAME}: $*"
	exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if difftastic is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token ${GITHUB_API_TOKEN}")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "${GH_REPO}" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
	# TODO: Adapt this. By default we simply list the tag names from GitHub releases.
	# Change this function if difftastic has other means of determining installable versions.
	list_github_tags
}

release_file_name() {
	local tool_name="$1"
	shift
	local version="$1"
	shift

	case "$(uname -o)" in
	Darwin) echo "${tool_name}-${version}-x86_64-apple-darwin.tar.gz" ;;
	GNU/Linux) echo "${tool_name}-${version}-x86_64-unknown-linux-gnu.tar.gz" ;;
	*)
		echo "Unsupported operating system: '$(uname -o)'" >&2
		exit 1
		;;
	esac
}

download_release() {
	local version filename url
	version="$1"
	shift
	filename="$1"
	shift

	case "$(uname -o)" in
	Darwin) url="${GH_REPO}/releases/download/${version}/difft-x86_64-apple-darwin.tar.gz" ;;
	GNU/Linux) url="${GH_REPO}/releases/download/${version}/difft-x86_64-unknown-linux-gnu.tar.gz" ;;
	*)
		echo "Unsupported operating system: '$(uname -o)'" >&2
		exit 1
		;;
	esac

	echo "* Downloading ${TOOL_NAME} release ${version}..."
	curl "${curl_opts[@]}" -o "${filename}" -C - "${url}" || fail "Could not download ${url}"
}

install_version() {
	local install_type="$1"
	shift
	local version="$1"
	shift
	local install_path="${1%/bin}/bin"
	shift

	if [ "${install_type}" != "version" ]; then
		fail "asdf-${TOOL_NAME} supports release installs only"
	fi

	(
		mkdir -p "${install_path}"
		cp -r "${ASDF_DOWNLOAD_PATH}"/* "${install_path}"

		local tool_cmd
		tool_cmd="$(echo "${TOOL_TEST}" | cut -d' ' -f1)"
		test -x "${install_path}/${tool_cmd}" || fail "Expected ${install_path}/${tool_cmd} to be executable."

		echo "${TOOL_NAME} ${version} installation was successful!"
	) || (
		rm -rf "${install_path}"
		fail "An error occurred while installing ${TOOL_NAME} ${version}."
	)
}
