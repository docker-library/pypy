#!/usr/bin/env bash
set -Eeuo pipefail

declare -A aliases=(
	['3.8']='3'
	['2.7']='2'
)

defaultDebianSuite='bullseye'

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

# sort version numbers with highest first
IFS=$'\n'; set -- $(sort -rV <<<"$*"); unset IFS

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		files="$(
			git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						if ($i ~ /^--from=/) {
							next
						}
						print $i
					}
				}
			'
		)"
		fileCommit Dockerfile $files
	)
}

getArches() {
	local repo="$1"; shift
	local officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/'

	eval "declare -g -A parentRepoToArches=( $(
		find -name 'Dockerfile' -exec awk '
				toupper($1) == "FROM" && $2 !~ /^('"$repo"'|scratch|.*\/.*)(:|$)/ {
					print "'"$officialImagesUrl"'" $2
				}
			' '{}' + \
			| sort -u \
			| xargs bashbrew cat --format '[{{ .RepoName }}:{{ .TagName }}]="{{ join " " .TagEntry.Architectures }}"'
	) )"
}
getArches 'pypy'

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

for version; do
	export version
	variants="$(jq -r '.[env.version].variants | map(@sh) | join(" ")' versions.json)"
	eval "variants=( $variants )"

	fullVersion="$(jq -r '.[env.version].version' versions.json)"

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

	for v in "${variants[@]}"; do
		dir="$version/$v"
		[ -f "$dir/Dockerfile" ] || continue
		variant="$(basename "$v")"

		commit="$(dirCommit "$dir")"

		variantAliases=( "${versionAliases[@]/%/-$variant}" )
		sharedTags=()
		case "$variant" in
			"$defaultDebianSuite" | windowsservercore-*)
				sharedTags=( "${versionAliases[@]}" )
				;;
			slim-"$defaultDebianSuite")
				variantAliases=(
					"${versionAliases[@]/%/-slim}"
					"${variantAliases[@]}"
				)
				;;
		esac
		variantAliases=( "${variantAliases[@]//latest-/}" )

		for windowsShared in windowsservercore nanoserver; do
			if [[ "$variant" == "$windowsShared"* ]]; then
				sharedTags+=( "${versionAliases[@]/%/-$windowsShared}" )
				sharedTags=( "${sharedTags[@]//latest-/}" )
				break
			fi
		done

		constraints=
		case "$v" in
			windows/*)
				variantArches="$(jq -r '
					.[env.version].arches
					| keys[]
					| select(startswith("windows-"))
				' versions.json | sort)"
				constraints="$variant"
				;;

			*)
				variantParent="$(awk 'toupper($1) == "FROM" { print $2; exit }' "$dir/Dockerfile")"
				variantArches="${parentRepoToArches[$variantParent]:-}"
				variantArches="$(
					comm -12 \
						<(
							jq -r '
								.[env.version].arches
								| keys[]
							' versions.json | sort
						) \
						<(xargs -n1 <<<"$variantArches" | sort)
				)"
				if [[ "$v" != *buster ]]; then
					# "pypy3: error while loading shared libraries: libffi.so.6: cannot open shared object file: No such file or directory"
					variantArches="$(sed -r -e '/s390x/d' <<<"$variantArches")"
				fi
				;;
		esac

		echo
		echo "Tags: $(join ', ' "${variantAliases[@]}")"
		if [ "${#sharedTags[@]}" -gt 0 ]; then
			echo "SharedTags: $(join ', ' "${sharedTags[@]}")"
		fi
		cat <<-EOE
			Architectures: $(join ', ' $variantArches)
			GitCommit: $commit
			Directory: $dir
		EOE
		[ -z "$constraints" ] || echo "Constraints: $constraints"
	done
done
