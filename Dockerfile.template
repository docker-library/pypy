FROM buildpack-deps:%%BASE%%

# ensure local pypy is preferred over distribution pypy
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
		tcl \
		tk \
	&& rm -rf /var/lib/apt/lists/*

ENV PYPY_VERSION %%PYPY_VERSION%%

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION %%PIP_VERSION%%

RUN set -ex; \
	\
# this "case" statement is generated via "update.sh"
	%%ARCH-CASE%%; \
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
		cd /usr/local/lib_pypy; \
		%%CMD%% _ssl_build.py; \
# TODO rebuild other cffi modules here too? (other _*_build.py files)
	fi

RUN set -ex; \
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
	rm -f get-pip.py

CMD ["%%CMD%%"]
