#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM debian:bullseye-slim

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
ENV PYPY_VERSION 7.3.19

RUN set -eux; \
	\
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
		'amd64') \
			url='https://downloads.python.org/pypy/pypy2.7-v7.3.19-linux64.tar.bz2'; \
			sha256='d38445508c2eaf14ebb380d9c1ded321c5ebeae31c7e66800173d83cb8ddf423'; \
			;; \
		'arm64') \
			url='https://downloads.python.org/pypy/pypy2.7-v7.3.19-aarch64.tar.bz2'; \
			sha256='fe89d4fd4af13f76dfe7315975003518cf176520e3ccec1544a88d174f50910e'; \
			;; \
		'i386') \
			url='https://downloads.python.org/pypy/pypy2.7-v7.3.19-linux32.tar.bz2'; \
			sha256='cc52df02b6926bd8645c1651cd7f6637ce51c2f352d0fb3c6b9330d15194b409'; \
			;; \
		*) echo >&2 "error: current architecture ($dpkgArch) does not have a corresponding PyPy $PYPY_VERSION binary release"; exit 1 ;; \
	esac; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		bzip2 \
		wget \
# sometimes "pypy" itself is linked against libexpat1 / libncurses5, sometimes they're ".so" files in "/opt/pypy/lib_pypy"
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
	ln -sv '/opt/pypy/bin/pypy' /usr/local/bin/; \
	\
# smoke test
	pypy --version; \
# verify (C)Python version is accurate
	pypyPython="$(pypy -c 'import sys; print(".".join(map(str, sys.version_info[0:3])))')"; \
	[ "$pypyPython" = '2.7.18' ]; \
	\
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	find /opt/pypy -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
# smoke test again, to be sure
	pypy --version; \
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
	apt-get update; \
	apt-get install -y --no-install-recommends wget; \
	rm -rf /var/lib/apt/lists/*; \
	\
	wget -O get-pip.py "$PYTHON_GET_PIP_URL"; \
	echo "$PYTHON_GET_PIP_SHA256 *get-pip.py" | sha256sum --check --strict -; \
	\
	pipVersion="$(pypy -c 'import ensurepip; print(ensurepip._PIP_VERSION)')"; \
	setuptoolsVersion="$(pypy -c 'import ensurepip; print(ensurepip._SETUPTOOLS_VERSION)')"; \
	\
	pypy get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip == $pipVersion" \
		"setuptools == $setuptoolsVersion" \
	; \
	apt-get purge -y --auto-remove wget; \
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

CMD ["pypy"]
