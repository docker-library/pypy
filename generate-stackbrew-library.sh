#!/usr/bin/env bash
set -Eeuo pipefail

declare -A aliases=(
	[3.6]='3'
	[2.7]='2'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

source '.architectures-lib'

versions=( */ )
versions=( "${versions[@]%/}" )

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		fileCommit \
			Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						print $i
					}
				}
			')
	)
}

cat <<-EOH
# this file is generated via https://github.com/docker-library/pypy/blob/$(fileCommit "$self")/$self

Maintainers: Tianon Gravi <admwiggin@gmail.com> (@tianon),
             Joseph Ferguson <yosifkit@gmail.com> (@yosifkit)
GitRepo: https://github.com/docker-library/pypy.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version in "${versions[@]}"; do
	commit="$(dirCommit "$version")"

	fullVersion="$(git show "$commit":"$version/Dockerfile" | awk '$1 == "ENV" && $2 == "PYPY_VERSION" { print $3; exit }')"
	#fullVersion="$version-$fullVersion"

	pypyVersionAliases=()
	while [ "${fullVersion%[.-]*}" != "$fullVersion" ]; do
		pypyVersionAliases+=( $fullVersion )
		fullVersion="${fullVersion%[.-]*}"
	done
	pypyVersionAliases+=( $fullVersion latest )

	versionAliases=()
	for va in "$version" ${aliases[$version]:-}; do
		versionAliases+=( "${pypyVersionAliases[@]/#/$va-}" )
		versionAliases=( "${versionAliases[@]//-latest}" )
		versionAliases=( "${versionAliases[@]//latest-}" )
		if [ "$va" = '3' ]; then
			# whichever release gets the coveted "pypy:3" alias gets "pypy:latest" too
			versionAliases+=( latest )
		fi
	done

	for variant in '' slim; do
		dir="$version${variant:+/$variant}"
		[ -f "$dir/Dockerfile" ] || continue

		commit="$(dirCommit "$dir")"

		variantAliases=( "${versionAliases[@]}" )
		if [ -n "$variant" ]; then
			variantAliases=( "${variantAliases[@]/%/-$variant}" )
			variantAliases=( "${variantAliases[@]//latest-/}" )
		fi

		variantParent="$(parent "$dir")"

		suite="${variantParent#*:}" # "jessie-slim", "stretch"
		suite="${suite%-slim}" # "jessie", "stretch"

		suiteAliases=( "${variantAliases[@]/%/-$suite}" )
		suiteAliases=( "${suiteAliases[@]//latest-/}" )
		variantAliases+=( "${suiteAliases[@]}" )

		variantArches="$(parentArches "$dir" "$variantParent")"

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			Architectures: $(join ', ' $variantArches)
			GitCommit: $commit
			Directory: $dir
		EOE
	done
done
