#!/usr/bin/env bash
set -Eeuo pipefail

# https://downloads.python.org/pypy/versions.json
# https://www.pypy.org/download.html
# https://downloads.python.org/pypy/
allVersions="$(wget -qO- 'https://downloads.python.org/pypy/versions.json' | jq -c '
	map(
		select(.stable and .latest_pypy) # do some minor pre-filtering to cut down the list of things to sort through
		| {
			version: .pypy_version,
			python: {
				version: .python_version,
				major: (.python_version | split(".")[0:2] | join(".")), # convert "x.y.z" into "x.y"
			},
			arches: (
				.files
				| map(
					{
						"darwin": "darwin",
						"linux": "linux",
						"win64": "windows",
					}[.platform] as $os
					| select($os)
					| (
						if $os != "linux" then
							$os + "-"
						else "" end + {
							"aarch64": "arm64v8",
							"i686": "i386",
							"s390x": "s390x",
							"x64": "amd64",
						}[.arch]
					) as $arch
					| select($arch)
					| { ($arch): { url: .download_url } }
				) | add
			),
		}
	)
')"

fullVersion="$(jq <<<"$allVersions" -r '.[0].version')"
export fullVersion

thisVersion="$(jq <<<"$allVersions" -c 'map(select(.version == env.fullVersion) | { (.python.major): . }) | add')"

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	shell="$(jq <<<"$thisVersion" -r 'keys_unsorted | map(@sh) | join(" ")')"
	eval "versions=( $shell )"
	json='{}'
else
	json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

sha256s="$(curl -fsSL --compressed 'https://www.pypy.org/checksums.html')"
scrape_sha256() {
	local tarball="$1"; shift

	# <p>pypy2.7-5.4.0 sha256:</p>
	# <pre class="literal-block">
	# ...
	# bdfea513d59dcd580970cb6f79f3a250d00191fd46b68133d5327e924ca845f8  pypy2-v5.4.0-linux64.tar.bz2
	# ...
	# </pre>
	grep -om1 -E "[a-f0-9]{64}  $tarball" <<<"$sha256s" \
		| cut -d' ' -f1
}

for version in "${versions[@]}"; do
	export version

	echo "$version: $fullVersion"

	doc="$(jq <<<"$thisVersion" -c '.[env.version]')"

	shell="$(jq <<<"$doc" -r '
		.arches
		| to_entries
		| map(
			"[" + (.key | @sh) + "]=" + (.value.url | @sh)
		)
		| join(" ")
	')"
	eval "declare -A arches=( $shell )"
	for arch in "${!arches[@]}"; do
		url="${arches[$arch]}"
		tarball="$(basename "$url")"
		if ! sha256="$(scrape_sha256 "$tarball")"; then
			echo >&2 "error: failed to find sha256 for '$version' on '$arch' ('$tarball')"
			echo >&2 "  URL: $url"
			exit 1
		fi
		export arch sha256
		doc="$(jq <<<"$doc" -c '.arches[env.arch].sha256 = env.sha256')"
	done

	json="$(jq <<<"$json" -c --argjson doc "$doc" '
		.[env.version] = $doc + {
			"get-pip": {
				# https://github.com/pypa/get-pip/releases/tag/20.3.4 (the last release to support Python 2)
				version: "3843bff3a0a61da5b63ea0b7d34794c5c51a2f11",
				url: "https://github.com/pypa/get-pip/raw/3843bff3a0a61da5b63ea0b7d34794c5c51a2f11/get-pip.py",
				sha256: "95c5ee602b2f3cc50ae053d716c3c89bea62c58568f64d7d25924d399b2d5218",
				# TODO use a newer commit for Python 3
			},
			variants: [
				(
					"bullseye",
					"buster",
					empty # trailing comma
				| ., "slim-" + .),

				if $doc.arches | keys | any(startswith("windows-")) then
					(
						"ltsc2022",
						"1809",
						empty # trailing comma
					| "windows/windowsservercore-" + .)
				else empty end
			],
		}
	')"
done

jq <<<"$json" -S . > versions.json
