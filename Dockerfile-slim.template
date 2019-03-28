FROM debian:%%BASE%%-slim

# ensure local pypy is preferred over distribution pypy
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
		ca-certificates \
		libexpat1 \
		libffi6 \
		libgdbm3 \
		libsqlite3-0 \
	&& rm -rf /var/lib/apt/lists/*

ENV PYPY_VERSION %%PYPY_VERSION%%

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION %%PIP_VERSION%%

RUN set -ex; \
	\
# this "case" statement is generated via "update.sh"
	%%ARCH-CASE%%; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		bzip2 \
		wget \
# sometimes "%%CMD%%" itself is linked against libncurses5, sometimes it's a ".so" file in "/usr/local/lib_pypy"
		libncurses5 \
	; \
	\
	wget -O pypy.tar.bz2 "https://bitbucket.org/pypy/pypy/downloads/%%TAR%%-v${PYPY_VERSION}-${pypyArch}.tar.bz2" --progress=dot:giga; \
	echo "$sha256 *pypy.tar.bz2" | sha256sum -c; \
	tar -xjC /usr/local --strip-components=1 -f pypy.tar.bz2; \
	find /usr/local/lib-python -depth -type d -a \( -name test -o -name tests \) -exec rm -rf '{}' +; \
	rm pypy.tar.bz2; \
	\
# smoke test
	%%CMD%% --version; \
	\
	if [ -f /usr/local/lib_pypy/_ssl_build.py ]; then \
# on pypy3, rebuild ffi bits for compatibility with Debian Stretch+ (https://github.com/docker-library/pypy/issues/24#issuecomment-409408657)
		apt-get install -y --no-install-recommends gcc libc6-dev libssl-dev; \
		cd /usr/local/lib_pypy; \
		%%CMD%% _ssl_build.py; \
# TODO rebuild other cffi modules here too? (other _*_build.py files)
	fi; \
	\
	wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
	\
	%%CMD%% get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	; \
# smoke test
	pip --version; \
	\
	rm -f get-pip.py; \
	\
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
# smoke test again, to be sure
	rm -rf /var/lib/apt/lists/*; \
	%%CMD%% --version; \
	pip --version

CMD ["%%CMD%%"]
