#!/bin/bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

source '.architectures-lib'

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

pipVersion="$(curl -fsSL 'https://pypi.org/pypi/pip/json' | jq -r .info.version)"
getPipCommit="$(curl -fsSL 'https://github.com/pypa/get-pip/commits/master/get-pip.py.atom' | tac|tac | awk -F '[[:space:]]*[<>/]+' '$2 == "id" && $3 ~ /Commit/ { print $4; exit }')"
getPipUrl="https://github.com/pypa/get-pip/raw/$getPipCommit/get-pip.py"
getPipSha256="$(curl -fsSL "$getPipUrl" | sha256sum | cut -d' ' -f1)"

sha256s="$(curl -fsSL 'https://pypy.org/download.html')"
scrapeSha256() {
	local pypy="$1"; shift
	local fullVersion="$1"; shift
	local arch="$1"; shift

	# <p>pypy2.7-5.4.0 sha256:</p>
	# <pre class="literal-block">
	# ...
	# bdfea513d59dcd580970cb6f79f3a250d00191fd46b68133d5327e924ca845f8  pypy2-v5.4.0-linux64.tar.bz2
	# ...
	# </pre>
	grep -om1 -E '[a-f0-9]{64}  '"$pypy-v$tryVersion"'-'"$arch"'.tar.bz2' <<<"$sha256s" \
		| cut -d' ' -f1
}

# see http://stackoverflow.com/a/2705678/433558
sed_escape_rhs() {
	echo "$@" | sed -e 's/[\/&]/\\&/g' | sed -e ':a;N;$!ba;s/\n/\\n/g'
}

for version in "${versions[@]}"; do
	case "$version" in
		3 | 3.*) cmd='pypy3'; base='buster' ;;
		2 | 2.*) cmd='pypy'; base='buster' ;;
		*) echo >&2 "error: unknown pypy variant $version"; exit 1 ;;
	esac
	pypy="pypy$version"

	# <td class="filelink"><a href="pypy3.6-v7.3.1-aarch64.tar.bz2">pypy3.6-v7.3.1-aarch64.tar.bz2</a></td>
	# <td class="filelink"><a href="pypy2.7-v7.3.1-aarch64.tar.bz2">pypy2.7-v7.3.1-aarch64.tar.bz2</a></td>
	IFS=$'\n'
	tryVersions=( $(
		curl -fsSL --compressed 'https://downloads.python.org/pypy/' \
			| sed -rn 's/^.*'"$pypy"'-v([0-9.]+(-alpha[0-9]*)?)-linux64.tar.bz2.*$/\1/gp' \
			| sort -rV
	) )
	unset IFS

	fullVersion=
	sha256sum=
	for tryVersion in "${tryVersions[@]}"; do
		if \
			sha256sum="$(scrapeSha256 "$pypy" "$tryVersion" 'linux64')" \
			&& [ -n "$sha256sum" ] \
		; then
			fullVersion="$tryVersion"
			break
		fi
	done
	if [ -z "$fullVersion" ]; then
		echo >&2 "error: cannot find suitable release for '$version'"
		exit 1
	fi

	# if our current version is newer than the version we just scraped, this must be a fluke/flake (https://github.com/docker-library/official-images/pull/6163)
	if currentVersion="$(awk '$1 == "ENV" && $2 == "PYPY_VERSION" { print $3; exit }' "$version/Dockerfile" 2>/dev/null)" && [ -n "$currentVersion" ] && [ "$currentVersion" != "$fullVersion" ]; then
		newVersion="$(
			{
				echo "$fullVersion"
				echo "$currentVersion"
			} | sort -rV | head -1
		)"
		if [ "$newVersion" = "$currentVersion" ]; then
			echo >&2 "error: scraped version ($fullVersion) is older than our current version ($currentVersion)!"
			echo >&2 "  cowardly bailing to avoid unnecessary churn"
			exit 1
		fi
	fi

	echo "$version: $fullVersion"

	linuxArchCase='dpkgArch="$(dpkg --print-architecture)"; '$'\\\n'
	linuxArchCase+=$'\t''case "${dpkgArch##*-}" in '$'\\\n'
	for dpkgArch in $(dpkgArches); do
		bashbrewArch="$(dpkgToBashbrewArch "$dpkgArch")"
		case "$version/$bashbrewArch" in
			2.7/s390x | 2.7/ppc64le)
				echo >&2 "warning: skipping $pypy on $bashbrewArch; https://bitbucket.org/pypy/pypy/issues/2646"
				continue
				;;
		esac
		pypyArch="$(dpkgToPyPyArch "$dpkgArch")"
		sha256="$(scrapeSha256 "$pypy" "$fullVersion" "$pypyArch")" || :
		if [ -z "$sha256" ]; then
			echo >&2 "warning: cannot find sha256 for $pypy-$fullVersion on arch $pypyArch ($bashbrewArch); skipping it"
			continue
		fi
		linuxArchCase+="# $bashbrewArch"$'\n'
		linuxArchCase+=$'\t\t'"$dpkgArch) pypyArch='$pypyArch'; sha256='$sha256' ;; "$'\\\n'
	done
	linuxArchCase+=$'\t\t''*) echo >&2 "error: current architecture ($dpkgArch) does not have a corresponding PyPy $PYPY_VERSION binary release"; exit 1 ;; '$'\\\n'
	linuxArchCase+=$'\t''esac'

	for variant in slim ''; do
		sed -r \
			-e 's!%%PYPY_VERSION%%!'"$fullVersion"'!g' \
			-e 's!%%PIP_VERSION%%!'"$pipVersion"'!g' \
			-e 's!%%PYTHON_GET_PIP_URL%%!'"$getPipUrl"'!' \
			-e 's!%%PYTHON_GET_PIP_SHA256%%!'"$getPipSha256"'!' \
			-e 's!%%TAR%%!'"$pypy"'!g' \
			-e 's!%%CMD%%!'"$cmd"'!g' \
			-e 's!%%BASE%%!'"$base"'!g' \
			-e 's!%%ARCH-CASE%%!'"$(sed_escape_rhs "$linuxArchCase")"'!g' \
			"Dockerfile${variant:+-$variant}.template" > "$version/$variant/Dockerfile"
	done
done
