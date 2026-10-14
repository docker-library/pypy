#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM debian:bookworm-slim

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates; \
	rm -rf /var/lib/apt/lists/*

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# ensure local pypy is preferred over distribution pypy
ENV PATH /opt/pypy/bin:$PATH

# Python 2.7.18
ENV PYPY_VERSION 8.0.1

RUN set -eux; \
	\
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
		'amd64') \
			url='https://downloads.python.org/pypy/pypy2.7-v8.0.1-linux64.tar.gz'; \
			sha256='78674cdf95eb4cb1dd5a9b68a70200387111cb29467f8a472ab7cf07a251653c'; \
			;; \
		'arm64') \
			url='https://downloads.python.org/pypy/pypy2.7-v8.0.1-aarch64.tar.gz'; \
			sha256='abd5bd601fc5af143a80d02c52b5f098f0096f9b0793140353e5e3d439676b85'; \
			;; \
		'i386') \
			url='https://downloads.python.org/pypy/pypy2.7-v8.0.1-linux32.tar.gz'; \
			sha256='956365de00b86c4741acd719caff28edf3df2306962f7767ca0e2c9a73e262e5'; \
			;; \
		*) echo >&2 "error: current architecture ($dpkgArch) does not have a corresponding PyPy $PYPY_VERSION binary release"; exit 1 ;; \
	esac; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		wget \
# sometimes "pypy" (or associated .so files) has dynamic links to different system libraries
# we install them here, and then use "ldd" further down to only keep what we actually need (which might even differ per architecture)
		libfreetype6 \
	; \
	\
	wget -O pypy.tar.gz "$url" --progress=dot:giga; \
	echo "$sha256 *pypy.tar.gz" | sha256sum --check --strict -; \
	mkdir /opt/pypy; \
	tar -xzC /opt/pypy --strip-components=1 -f pypy.tar.gz; \
	find /opt/pypy/lib* -depth -type d -a \( -name test -o -name tests \) -exec rm -rf '{}' +; \
	rm pypy.tar.gz; \
	\
# delete a few (sometimes) problematic bundled libraries
	rm -v /opt/pypy/lib/libtk*.so /opt/pypy/lib/libz.so*; \
	\
	ln -sv '/opt/pypy/bin/pypy' /usr/local/bin/; \
	\
# smoke test
	pypy --version; \
	\
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	export shellPid="$$"; \
	find /opt/pypy -type f -executable -exec ldd '{}' ';' \
		| grep -vE 'lib(tcl|tk|X[a-z]*)[0-9]*[.]' \
		| awk '/not found/ { print >> "/dev/stderr"; system("kill -9 -$shellPid") } /=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1 || index(so, "/opt/pypy/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -rt dpkg-query --search \
# https://manpages.debian.org/bookworm/dpkg/dpkg-query.1.en.html#S (we ignore diversions and it'll be really unusual for more than one package to provide any given .so file)
		| awk 'sub(":$", "", $1) { print $1 }' \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
# smoke test again, to be sure
	pypy --version; \
	\
	pypy -m ensurepip --default-pip; \
	pip --version; \
# https://github.com/docker-library/python/issues/952
# https://github.com/docker-library/python/issues/1023
	pip install --disable-pip-version-check --no-cache-dir --no-compile 'wheel<0.46'; \
	\
	find /opt/pypy -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' +

CMD ["pypy"]
