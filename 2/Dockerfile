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

ENV PYPY_VERSION 5.8.0
ENV PYPY_SHA256SUM 6274292d0e954a2609b15978cde6efa30942ba20aa5d2acbbf1c70c0a54e9b1e

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 9.0.1

RUN set -ex; \
	wget -O pypy.tar.bz2 "https://bitbucket.org/pypy/pypy/downloads/pypy2-v${PYPY_VERSION}-linux64.tar.bz2"; \
	echo "$PYPY_SHA256SUM *pypy.tar.bz2" | sha256sum -c; \
	tar -xjC /usr/local --strip-components=1 -f pypy.tar.bz2; \
	rm pypy.tar.bz2

RUN set -ex; \
	\
	wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
	\
	pypy get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	; \
	pip --version; \
	\
	rm -f get-pip.py

CMD ["pypy"]
