#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM mcr.microsoft.com/windows/servercore:ltsc2022

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# PATH isn't actually set in the Docker image, so we have to set it from within the container
RUN $newPath = ('C:\pypy;C:\pypy\Scripts;{0}' -f $env:PATH); \
	Write-Host ('Updating PATH: {0}' -f $newPath); \
	[Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::Machine); \
	Write-Host 'Complete.'
# doing this first to share cache across versions more aggressively

# install Microsoft Visual C++ Redistributable
RUN $url = 'https://download.microsoft.com/download/6/A/A/6AA4EDFF-645B-48C5-81CC-ED5963AEAD48/vc_redist.x64.exe'; \
	Write-Host ('Downloading {0} ...' -f $url); \
	Invoke-WebRequest -Uri $url -OutFile 'vc.exe'; \
	\
	$sha256 = 'da66717784c192f1004e856bbcf7b3e13b7bf3ea45932c48e4c9b9a50ca80965'; \
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

# Python 3.11.11
ENV PYPY_VERSION 7.3.19

RUN $url = 'https://downloads.python.org/pypy/pypy3.11-v7.3.19-win64.zip'; \
	Write-Host ('Downloading {0} ...' -f $url); \
	Invoke-WebRequest -Uri $url -OutFile 'pypy.zip'; \
	\
	$sha256 = 'b61c7c1dbf879eda6f779c374bfbbeecd3f618ada08404705a1a19d39df48dbd'; \
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
	Rename-Item -Path C:\pypy3.11-v7.3.19-win64 -NewName C:\pypy; \
	\
	Write-Host 'Verifying install ("pypy --version") ...'; \
	pypy --version; \
	\
	Write-Host 'Installing pip ...'; \
	pypy -m ensurepip --default-pip; \
	\
	Write-Host 'Verifying pip install ...'; \
	pip --version; \
	\
	Write-Host 'Installing "wheel" (backwards compat) ...'; \
# https://github.com/docker-library/python/issues/952
# https://github.com/docker-library/python/issues/1023
	pip install --disable-pip-version-check --no-cache-dir --no-compile 'wheel<0.46'; \
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
