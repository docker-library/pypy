#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM buildpack-deps:bookworm

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

# Python 3.11.17
ENV PYPY_VERSION 8.0.1

RUN set -eux; \
	\
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
		'amd64') \
			url='https://downloads.python.org/pypy/pypy3.11-v8.0.1-linux64.tar.gz'; \
			sha256='706965bcf372752ba69dafd59d860e51bc2fadbb0f8a47cec3426125d7058ceb'; \
			;; \
		'arm64') \
			url='https://downloads.python.org/pypy/pypy3.11-v8.0.1-aarch64.tar.gz'; \
			sha256='5b568e1515dee46df58c9844dba95921c69dfd9f38ebf9e0f091caad5e10cd0c'; \
			;; \
		'i386') \
			url='https://downloads.python.org/pypy/pypy3.11-v8.0.1-linux32.tar.gz'; \
			sha256='fdafc3aa7a17e25f7ba63a6a2baa91c4a765c1c9a99149759e583f68e68115e5'; \
			;; \
		*) echo >&2 "error: current architecture ($dpkgArch) does not have a corresponding PyPy $PYPY_VERSION binary release"; exit 1 ;; \
	esac; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
# sometimes "pypy3" (or associated .so files) has dynamic links to different system libraries
# we install them here, and then use "ldd" further down to only keep what we actually need (which might even differ per architecture)
		libfontconfig1 \
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
	ln -sv '/opt/pypy/bin/pypy3' /usr/local/bin/; \
	\
# smoke test
	pypy3 --version; \
	\
# rebuild several cffi modules for compatibility
	cd /opt/pypy/lib/pypy3.11; \
	if [ -f _gdbm_build.py ]; then \
		pypy3 _gdbm_build.py; \
	fi; \
	if [ -f _ssl_build.py ]; then \
# https://github.com/docker-library/pypy/issues/24#issuecomment-409408657
		pypy3 _ssl_build.py; \
	fi; \
	if [ -f _lzma_build.py ]; then \
# https://github.com/docker-library/pypy/issues/42
		pypy3 _lzma_build.py; \
	fi; \
	if [ -f _sqlite3_build.py ]; then \
# https://github.com/docker-library/pypy/issues/68
		pypy3 _sqlite3_build.py; \
	fi; \
	if [ -f _tkinter/tklib_build.py ]; then \
		apt-get install -y --no-install-recommends tk-dev; \
		pypy3 _tkinter/tklib_build.py; \
	fi; \
# TODO rebuild other cffi modules here too? (other _*_build.py files; see https://github.com/pypy/pypy/blob/0f013f041fff7fb9a23b22dae8437e82beb6a279/lib_pypy/pypy_tools/build_cffi_imports.py#L25-L40)
	\
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	export shellPid="$$"; \
	find /opt/pypy -type f -executable -exec ldd '{}' ';' \
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
	pypy3 --version; \
	\
	pypy3 -m ensurepip --default-pip; \
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

CMD ["pypy3"]
