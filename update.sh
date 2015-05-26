#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
	case "$version" in
		3) pypy="pypy$version";;
		*) pypy='pypy';;
	esac
	# <td class="name"><a class="execute" href="/pypy/pypy/downloads/pypy-2.4.0-linux64.tar.bz2">pypy-2.4.0-linux64.tar.bz2</a></td>
	# <td class="name"><a class="execute" href="/pypy/pypy/downloads/pypy3-2.4.0-linux64.tar.bz2">pypy3-2.4.0-linux64.tar.bz2</a></td>
	fullVersion="$(curl -sSL 'https://bitbucket.org/pypy/pypy/downloads' | grep -E "$pypy"'-([0-9.]+)-linux64.tar.bz2' | sed -r 's/^.*'"$pypy"'-([0-9.]+)-linux64.tar.bz2.*$/\1/' | sort -V | tail -1)"
	
	(
		set -x
		sed -ri 's/^(ENV PYPY_VERSION) .*/\1 '"$fullVersion"'/' "$version"{,/slim}/Dockerfile
		sed -ri 's/^(FROM pypy):.*/\1:'"$version"'/' "$version/onbuild/Dockerfile"
	)
done
