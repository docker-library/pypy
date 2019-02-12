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
	echo "$sha256s" \
		| grep -m1 -E '[a-f0-9]{64}  '"$pypy-v$tryVersion"'-'"$arch"'.tar.bz2' \
		| cut -d' ' -f1
}

# see http://stackoverflow.com/a/2705678/433558
sed_escape_rhs() {
	echo "$@" | sed -e 's/[\/&]/\\&/g' | sed -e ':a;N;$!ba;s/\n/\\n/g'
}

travisEnv=
for version in "${versions[@]}"; do
	case "$version" in
		3 | 3.*) cmd='pypy3' ;;
		2 | 2.*) cmd='pypy' ;;
		*) echo >&2 "error: unknown pypy variant $version"; exit 1 ;;
	esac
	pypy="pypy$version"

	# <td class="name"><a class="execute" href="/pypy/pypy/downloads/pypy-2.4.0-linux64.tar.bz2">pypy-2.4.0-linux64.tar.bz2</a></td>
	# <td class="name"><a class="execute" href="/pypy/pypy/downloads/pypy3-2.4.0-linux64.tar.bz2">pypy3-2.4.0-linux64.tar.bz2</a></td>
	IFS=$'\n'
	tryVersions=( $(
		curl -fsSL 'https://bitbucket.org/pypy/pypy/downloads/' \
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

	echo "$version: $fullVersion"

	linuxArchCase='dpkgArch="$(dpkg --print-architecture)"; '$'\\\n'
	linuxArchCase+=$'\t''case "${dpkgArch##*-}" in '$'\\\n'
	for dpkgArch in $(dpkgArches); do
		pypyArch="$(dpkgToPyPyArch "$dpkgArch")"
		sha256="$(scrapeSha256 "$pypy" "$fullVersion" "$pypyArch")" || :
		if [ -z "$sha256" ]; then
			echo >&2 "warning: cannot find sha256 for $pypy-$fullVersion on arch $pypyArch ($dpkgArch); skipping it"
			continue
		fi
		bashbrewArch="$(dpkgToBashbrewArch "$dpkgArch")"
		linuxArchCase+="# $bashbrewArch"$'\n'
		linuxArchCase+=$'\t\t'"$dpkgArch) pypyArch='$pypyArch'; sha256='$sha256' ;; "$'\\\n'
	done
	linuxArchCase+=$'\t\t''*) echo >&2 "error: current architecture ($dpkgArch) does not have a corresponding PyPy $PYPY_VERSION binary release"; exit 1 ;; '$'\\\n'
	linuxArchCase+=$'\t''esac'

	for variant in slim ''; do
		sed -r \
			-e 's!%%PYPY_VERSION%%!'"$fullVersion"'!g' \
			-e 's!%%PIP_VERSION%%!'"$pipVersion"'!g' \
			-e 's!%%TAR%%!'"$pypy"'!g' \
			-e 's!%%CMD%%!'"$cmd"'!g' \
			-e 's!%%ARCH-CASE%%!'"$(sed_escape_rhs "$linuxArchCase")"'!g' \
			"Dockerfile${variant:+-$variant}.template" > "$version/$variant/Dockerfile"
		travisEnv='\n  - VERSION='"$version VARIANT=$variant$travisEnv"
	done
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
