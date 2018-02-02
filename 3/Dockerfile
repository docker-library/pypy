FROM buildpack-deps:jessie

# ensure local pypy is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
		tcl \
		tk \
	&& rm -rf /var/lib/apt/lists/*

ENV PYPY_VERSION 5.10.0

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 9.0.1

RUN set -ex; \
	\
# this "case" statement is generated via "update.sh"
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
# amd64
		amd64) pypyArch='linux64'; sha256='aa4fb52fb858d973dd838dcf8d74f30705e5afdf1150acb8e056eb99353dfe77' ;; \
# arm32v5
		armel) pypyArch='linux-armel'; sha256='c2cc529befb3e1f2ef8bd4e96af4a823c52ef2d180b0b3bd87511c5b47d59210' ;; \
# i386
		i386) pypyArch='linux32'; sha256='529bc3b11edbdcdd676d90c805b8f607f6eedd5f0ec457a31bbe09c03f5bebfe' ;; \
		*) echo >&2 "error: current architecture ($dpkgArch) does not have a corresponding PyPy $PYPY_VERSION binary release"; exit 1 ;; \
	esac; \
	\
	wget -O pypy.tar.bz2 "https://bitbucket.org/pypy/pypy/downloads/pypy3-v${PYPY_VERSION}-${pypyArch}.tar.bz2"; \
	echo "$sha256 *pypy.tar.bz2" | sha256sum -c; \
	tar -xjC /usr/local --strip-components=1 -f pypy.tar.bz2; \
	rm pypy.tar.bz2; \
	\
	pypy3 --version

RUN set -ex; \
	\
	wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
	\
	pypy3 get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	; \
	pip --version; \
	\
	rm -f get-pip.py

CMD ["pypy3"]
