#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM mcr.microsoft.com/windows/servercore:1809

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# https://github.com/docker-library/python/issues/147
ENV PYTHONIOENCODING UTF-8

# PATH isn't actually set in the Docker image, so we have to set it from within the container
RUN $newPath = ('C:\pypy;C:\pypy\Scripts;{0}' -f $env:PATH); \
	Write-Host ('Updating PATH: {0}' -f $newPath); \
	[Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::Machine); \
	Write-Host 'Complete.'
# doing this first to share cache across versions more aggressively

# install Microsoft Visual C++ Redistributable
RUN $url = 'https://download.microsoft.com/download/6/A/A/6AA4EDFF-645B-48C5-81CC-ED5963AEAD48/vc_redist.x86.exe'; \
	Write-Host ('Downloading {0} ...' -f $url); \
	Invoke-WebRequest -Uri $url -OutFile 'vc.exe'; \
	\
	$sha256 = '12a69af8623d70026690ba14139bf3793cc76c865759cad301b207c1793063ed'; \
	Write-Host ('Verifying sha256 ({0}) ...' -f $sha256); \
	if ((Get-FileHash vc.exe -Algorithm sha256).Hash -ne $sha256) { \
		Write-Host 'FAILED!'; \
		exit 1; \
	}; \
	\
	Write-Host 'Installing ...'; \
	Start-Process \
		-NoNewWindow \
		-Wait \
		-FilePath .\vc.exe \
		-ArgumentList @( \
			'/install', \
			'/quiet', \
			'/norestart' \
		); \
	\
	Write-Host 'Removing ...'; \
	Remove-Item vc.exe -Force; \
	\
	Write-Host 'Complete.'

ENV PYPY_VERSION 7.3.3

RUN $url = 'https://downloads.python.org/pypy/pypy2.7-v7.3.3-win32.zip'; \
	Write-Host ('Downloading {0} ...' -f $url); \
	Invoke-WebRequest -Uri $url -OutFile 'pypy.zip'; \
	\
	$sha256 = 'b3e660dae8d25d8278fd6a0db77e76a16ac9a8c1dca22e7e103d39ed696dc69e'; \
	Write-Host ('Verifying sha256 ({0}) ...' -f $sha256); \
	if ((Get-FileHash pypy.zip -Algorithm sha256).Hash -ne $sha256) { \
		Write-Host 'FAILED!'; \
		exit 1; \
	}; \
	\
	Write-Host 'Expanding ...'; \
	Expand-Archive pypy.zip -DestinationPath C:\; \
	\
	Write-Host 'Removing ...'; \
	Remove-Item pypy.zip -Force; \
	\
	Write-Host 'Renaming ...'; \
	Rename-Item -Path C:\pypy2.7-v7.3.3-win32 -NewName C:\pypy; \
	\
	Write-Host 'Verifying install ("pypy --version") ...'; \
	pypy --version; \
	\
	Write-Host 'Cleanup install ...'; \
	Get-ChildItem \
		-Path C:\pypy \
		-Include @( 'test', 'tests' ) \
		-Directory \
		-Recurse \
		| Remove-Item -Force -Recurse; \
	Get-ChildItem \
		-Path C:\pypy \
		-Include @( '*.pyc', '*.pyo' ) \
		-File \
		-Recurse \
		| Remove-Item -Force; \
	\
	Write-Host 'Complete.'

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 20.3.4
# https://github.com/pypa/get-pip
ENV PYTHON_GET_PIP_URL https://github.com/pypa/get-pip/raw/3843bff3a0a61da5b63ea0b7d34794c5c51a2f11/get-pip.py
ENV PYTHON_GET_PIP_SHA256 95c5ee602b2f3cc50ae053d716c3c89bea62c58568f64d7d25924d399b2d5218

RUN Write-Host ('Downloading get-pip.py ({0}) ...' -f $env:PYTHON_GET_PIP_URL); \
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
	Invoke-WebRequest -Uri $env:PYTHON_GET_PIP_URL -OutFile 'get-pip.py'; \
	Write-Host ('Verifying sha256 ({0}) ...' -f $env:PYTHON_GET_PIP_SHA256); \
	if ((Get-FileHash 'get-pip.py' -Algorithm sha256).Hash -ne $env:PYTHON_GET_PIP_SHA256) { \
		Write-Host 'FAILED!'; \
		exit 1; \
	}; \
	\
	Write-Host ('Installing "pip == {0}" ...' -f $env:PYTHON_PIP_VERSION); \
	pypy get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		('pip == {0}' -f $env:PYTHON_PIP_VERSION) \
	; \
	Remove-Item get-pip.py -Force; \
	\
	Write-Host 'Verifying pip install ...'; \
	pip --version; \
	\
	Write-Host 'Cleanup install ...'; \
	Get-ChildItem \
		-Path C:\pypy \
		-Include @( 'test', 'tests' ) \
		-Directory \
		-Recurse \
		| Remove-Item -Force -Recurse; \
	Get-ChildItem \
		-Path C:\pypy \
		-Include @( '*.pyc', '*.pyo' ) \
		-File \
		-Recurse \
		| Remove-Item -Force; \
	\
	Write-Host 'Complete.'

CMD ["pypy"]
