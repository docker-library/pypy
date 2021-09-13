#!/usr/bin/env bash
set -Eeuo pipefail

# see https://downloads.python.org/pypy/
declare -A pypyArches=(
	['amd64']='linux64'
	['arm32v5']='linux-armel'
	['arm32v7']='linux-armhf-raring'
	['arm64v8']='aarch64'
	['i386']='linux32'
	['windows-amd64']='win64'

	# see https://foss.heptapod.net/pypy/pypy/-/issues/2646 for some s390x/ppc64le caveats (mitigated in 3.x via https://github.com/docker-library/pypy/issues/24#issuecomment-476873691)
	['ppc64le']='ppc64le'
	['s390x']='s390x'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
	json='{}'
else
	json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

sha256s="$(curl -fsSL --compressed 'https://www.pypy.org/checksums.html')"
pypy_tarball() {
	local pypy="$1"; shift
	local fullVersion="$1"; shift
	local arch="$1"; shift

	local ext='tar.bz2'
	if [ "$arch" = 'win64' ]; then
		ext='zip'
	fi

	echo "pypy$pypy-v$fullVersion-$arch.$ext"
}
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

downloads="$(curl -fsSL --compressed 'https://downloads.python.org/pypy/')"

for version in "${versions[@]}"; do
	export version

	IFS=$'\n'
	tryVersions=( $(
		sed -rn 's/^.*pypy'"$version"'-v([0-9.]+(-alpha[0-9]*)?)-'"${pypyArches['amd64']}"'[.]tar[.]bz2.*$/\1/gp' <<<"$downloads" \
			| sort -rV
	) )
	unset IFS

	fullVersion=
	pypyArch="${pypyArches['amd64']}"
	tarball=
	sha256=
	for tryVersion in "${tryVersions[@]}"; do
		if tarball="$(pypy_tarball "$version" "$tryVersion" "$pypyArch")" && sha256="$(scrape_sha256 "$tarball")" && [ -n "$sha256" ]; then
			fullVersion="$tryVersion"
			break
		fi
	done
	if [ -z "$fullVersion" ]; then
		echo >&2 "error: cannot find suitable release for '$version'"
		exit 1
	fi

	export fullVersion tarball sha256
	doc="$(jq -nc '
		{
			version: env.fullVersion,
			arches: {
				amd64: {
					sha256: env.sha256,
					url: ("https://downloads.python.org/pypy/" + env.tarball),
				},
			},
			"get-pip": {
				# https://github.com/pypa/get-pip/releases/tag/20.3.4 (the last release to support Python 2)
				version: "3843bff3a0a61da5b63ea0b7d34794c5c51a2f11",
				url: "https://github.com/pypa/get-pip/raw/3843bff3a0a61da5b63ea0b7d34794c5c51a2f11/get-pip.py",
				sha256: "95c5ee602b2f3cc50ae053d716c3c89bea62c58568f64d7d25924d399b2d5218",
				# TODO use a newer commit for Python 3
			},
		}
	')"

	# if our current version is newer than the version we just scraped, this must be a fluke/flake (https://github.com/docker-library/official-images/pull/6163)
	if \
		currentVersion="$(
			jq -r '.[env.version].version // ""' versions.json 2>/dev/null
		)" \
		&& [ -n "$currentVersion" ] \
		&& [ "$currentVersion" != "$fullVersion" ] \
		&& newVersion="$(
			{
				echo "$fullVersion"
				echo "$currentVersion"
			} | sort -rV | head -1
		)" \
		&& [ "$newVersion" = "$currentVersion" ] \
	; then
		echo >&2 "error: scraped version ($fullVersion) is older than our current version ($currentVersion)!"
		echo >&2 "  cowardly bailing to avoid unnecessary churn"
		exit 1
	fi

	echo "$version: $fullVersion"

	for bashbrewArch in "${!pypyArches[@]}"; do
		case "$version/$bashbrewArch" in
			*/amd64)
				# we already collected the amd64 sha256 above
				continue
				;;

			2.7/s390x | 2.7/ppc64le)
				echo >&2 "warning: skipping $version on $bashbrewArch; https://foss.heptapod.net/pypy/pypy/-/issues/2646"
				continue
				;;
		esac

		pypyArch="${pypyArches["$bashbrewArch"]}"
		if tarball="$(pypy_tarball "$version" "$fullVersion" "$pypyArch")" && sha256="$(scrape_sha256 "$tarball")" && [ -n "$sha256" ]; then
			export bashbrewArch tarball sha256
			doc="$(jq <<<"$doc" -c '
				.arches[env.bashbrewArch] = {
					sha256: env.sha256,
					url: ("https://downloads.python.org/pypy/" + env.tarball),
				}
			')"
		fi
	done

	json="$(jq <<<"$json" -c --argjson doc "$doc" '
		.[env.version] = $doc + {
			variants: [
				(
					"bullseye",
					"buster"
				| ., "slim-" + .),

				if $doc.arches | keys | any(startswith("windows-")) then
					(
						"1809"
					| "windows/windowsservercore-" + .)
				else empty end
			],
		}
	')"
done

jq <<<"$json" -S . > versions.json
