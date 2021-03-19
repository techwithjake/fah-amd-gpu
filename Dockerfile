  
FROM ubuntu:20.04

ARG AMDGPU_PRO_VERSION=20.45-1188099-ubuntu-20.04
ARG FAH_CLIENT_MAJOR_V=7.6
ARG FAH_CLIENT_VERSION=7.6.9

ENV DEBIAN_FRONTEND noninteractive

# Install prerequisite packages and nice to have tools
RUN apt-get update && \
    apt-get -y install --no-install-recommends wget ca-certificates apt-utils xz-utils clinfo

# Fetch and extract the AMDGPU userland driver, setup as a local APT repo
RUN wget -qO- --referer=https://support.amd.com https://www2.ati.com/drivers/linux/amdgpu-pro-${AMDGPU_PRO_VERSION}.tar.xz | \
    tar -C /opt -Jx && \
    mv /opt/amdgpu-pro-${AMDGPU_PRO_VERSION} /opt/amdgpu-pro-repo && \
    echo "deb [trusted=yes] file:/opt/amdgpu-pro-repo /" > /etc/apt/sources.list.d/amdgpu-pro.list && \
    apt-get update --allow-insecure-repositories

# Install legacy opencl driver. Allow again to install non-signed packages.
RUN apt-get install -y clinfo-amdgpu-pro opencl-orca-amdgpu-pro-icd ocl-icd-libopencl1 && \
    cd /usr/lib/x86_64-linux-gnu && ln -s libOpenCL.so.1 libOpenCL.so

# Cleanup
RUN rm -rf /etc/apt/sources.list.d/amdgpu-pro.list /opt/amdgpu-pro-repo

# Fetch the F@H Client
RUN wget -qO /tmp/fah.deb https://download.foldingathome.org/releases/public/release/fahclient/debian-stable-64bit/v${FAH_CLIENT_MAJOR_V}/fahclient_${FAH_CLIENT_VERSION}_amd64.deb

# Install the F@H Client
RUN mkdir -p /usr/share/doc/fahclient && \
    touch /usr/share/doc/fahclient/sample-config.xml && \
    dpkg --install --no-triggers /tmp/fah.deb && rm /tmp/fah.deb

# Setup the unprivileged user to run F@H Client
RUN addgroup --gid 870 fah && \
    adduser --uid 870 --gid 870 --gecos "Folding at Home" --disabled-password fah && \
    usermod -aG video fah

USER fah

# Plant the GPU whitelist file (F@H Client is supposed to automatically
# download this as needed, but I've seen mixed results depending on such.)
ADD --chown=fah:fah https://apps.foldingathome.org/GPUs.txt /fah/GPUs.txt

WORKDIR /fah
EXPOSE 7396 36330

CMD FAHClient
