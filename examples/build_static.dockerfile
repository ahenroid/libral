#
# Libral static build using Docker build environment
#
# Usage examples:
# Build image:
#   docker build -t libral-static -f examples/build_static.dockerfile examples
# Build libral:
#   docker run --rm -v $(pwd):/usr/src/libral libral-static bash -c
#     'rm -rf build && mkdir build && cd build && \
#      ${CMAKE} -DLIBRAL_STATIC=ON .. && make && ../examples/dpack'
#

FROM centos:5

# Install build tools and libraries
RUN rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-pc1-el-5.noarch.rpm && \
    rpm -ivh http://pl-build-tools.delivery.puppetlabs.net/yum/el/5/x86_64/pl-build-tools-release-22.0.3-1.el5.noarch.rpm && \
    yum update -y && \
    yum -y install puppet-agent pl-boost pl-cmake pl-yaml-cpp pl-gcc zlib-devel libselinux-devel curl make pkgconfig openssl-devel curl-devel expat-devel
ENV PATH=/opt/pl-build-tools/bin:$PATH PKG_CONFIG_PATH=/opt/puppetlabs/puppet/lib/pkgconfig CMAKE="/opt/pl-build-tools/bin/cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/pl-build-toolchain.cmake -DCMAKE_PREFIX_PATH=/opt/pl-build-tools -DCMAKE_INSTALL_PREFIX=/opt/puppetlabs/puppet"

# Build Git (pre-built package not available)
RUN mkdir -p /usr/src/git && \
    curl -sL https://github.com/git/git/archive/master.tar.gz | tar -xzC /usr/src/git --strip-components 1 && \
    cd /usr/src/git && \
    ln -s /opt/pl-build-tools/bin/gcc /opt/pl-build-tools/bin/cc && \
    yum -y install gettext && \
    make all install prefix=/usr NO_TCLTK=1 && \
    yum -y remove gettext && \
    rm -rf /usr/src/git /opt/pl-build-tools/bin/cc

# Build Leatherman
RUN git -C /usr/src clone --branch 0.10.1 https://github.com/puppetlabs/leatherman && \
    mkdir -p /usr/src/leatherman/build && \
    cd /usr/src/leatherman/build && \
    ${CMAKE} -DBOOST_STATIC=ON .. && \
    make all install

# Build Libral
RUN git -C /usr/src clone https://github.com/puppetlabs/libral && \
    mkdir -p /usr/src/libral/build && \
    cd /usr/src/libral/build && \
    ${CMAKE} -DLIBRAL_STATIC=ON .. && \
    make && \
    mkdir -p /usr/share/augeas/lenses/dist

# Setup system files for dpack
COPY augeas-base/* /usr/share/augeas/lenses/dist/
RUN ln -s /etc/redhat-release /etc/system-release

WORKDIR /usr/src/libral

CMD ["bash"]
