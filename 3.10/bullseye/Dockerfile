#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM buildpack-deps:bullseye

# runtime dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		tcl \
		tk \
	; \
	rm -rf /var/lib/apt/lists/*

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# ensure local pypy3 is preferred over distribution pypy3
ENV PATH /opt/pypy/bin:$PATH

# Python 3.10.12
ENV PYPY_VERSION 7.3.12

RUN set -eux; \
	\
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
		'amd64') \
			url='https://downloads.python.org/pypy/pypy3.10-v7.3.12-linux64.tar.bz2'; \
			sha256='6c577993160b6f5ee8cab73cd1a807affcefafe2f7441c87bd926c10505e8731'; \
			;; \
		'arm64') \
			url='https://downloads.python.org/pypy/pypy3.10-v7.3.12-aarch64.tar.bz2'; \
			sha256='26208b5a134d9860a08f74cce60960005758e82dc5f0e3566a48ed863a1f16a1'; \
			;; \
		'i386') \
			url='https://downloads.python.org/pypy/pypy3.10-v7.3.12-linux32.tar.bz2'; \
			sha256='811667825ae58ada4b7c3d8bc1b5055b9f9d6a377e51aedfbe0727966603f60e'; \
			;; \
		's390x') \
			url='https://downloads.python.org/pypy/pypy3.10-v7.3.12-s390x.tar.bz2'; \
			sha256='043c13a585479428b463ab69575a088db74aadc16798d6e677d97f563585fee3'; \
			;; \
		*) echo >&2 "error: current architecture ($dpkgArch) does not have a corresponding PyPy $PYPY_VERSION binary release"; exit 1 ;; \
	esac; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
# sometimes "pypy3" itself is linked against libexpat1 / libncurses5, sometimes they're ".so" files in "/opt/pypy/lib/pypy3.10"
		libexpat1 \
		libncurses5 \
		libncursesw6 \
		libsqlite3-0 \
# (so we'll add them temporarily, then use "ldd" later to determine which to keep based on usage per architecture)
	; \
	\
	wget -O pypy.tar.bz2 "$url" --progress=dot:giga; \
	echo "$sha256 *pypy.tar.bz2" | sha256sum --check --strict -; \
	mkdir /opt/pypy; \
	tar -xjC /opt/pypy --strip-components=1 -f pypy.tar.bz2; \
	find /opt/pypy/lib* -depth -type d -a \( -name test -o -name tests \) -exec rm -rf '{}' +; \
	rm pypy.tar.bz2; \
	\
	ln -sv '/opt/pypy/bin/pypy3' /usr/local/bin/; \
	\
# smoke test
	pypy3 --version; \
	\
	cd /opt/pypy/lib/pypy3.10; \
# on pypy3, rebuild gdbm ffi bits for compatibility with Debian Stretch+
	if [ -f _gdbm_build.py ]; then \
		pypy3 _gdbm_build.py; \
	fi; \
# https://github.com/docker-library/pypy/issues/24#issuecomment-409408657
	if [ -f _ssl_build.py ]; then \
		pypy3 _ssl_build.py; \
	fi; \
# https://github.com/docker-library/pypy/issues/42
	if [ -f _lzma_build.py ]; then \
		pypy3 _lzma_build.py; \
	fi; \
# https://github.com/docker-library/pypy/issues/68
	if [ -f _sqlite3_build.py ]; then \
		pypy3 _sqlite3_build.py; \
	fi; \
# TODO rebuild other cffi modules here too? (other _*_build.py files)
	\
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	find /opt/pypy -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
# smoke test again, to be sure
	pypy3 --version; \
	\
	find /opt/pypy -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' +

# https://github.com/pypa/get-pip
ENV PYTHON_GET_PIP_URL https://github.com/pypa/get-pip/raw/3843bff3a0a61da5b63ea0b7d34794c5c51a2f11/get-pip.py
ENV PYTHON_GET_PIP_SHA256 95c5ee602b2f3cc50ae053d716c3c89bea62c58568f64d7d25924d399b2d5218

RUN set -ex; \
	\
	wget -O get-pip.py "$PYTHON_GET_PIP_URL"; \
	echo "$PYTHON_GET_PIP_SHA256 *get-pip.py" | sha256sum --check --strict -; \
	\
	pipVersion="$(pypy3 -c 'import ensurepip; print(ensurepip._PIP_VERSION)')"; \
	setuptoolsVersion="$(pypy3 -c 'import ensurepip; print(ensurepip._SETUPTOOLS_VERSION)')"; \
	\
	pypy3 get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip == $pipVersion" \
		"setuptools == $setuptoolsVersion" \
	; \
# smoke test
	pip --version; \
	\
	find /opt/pypy -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' +; \
	rm -f get-pip.py

CMD ["pypy3"]
