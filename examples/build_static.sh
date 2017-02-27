#!/bin/bash
#
# Libral static build using Puppet VMpooler systems
#

ME=$(basename "$0")

if ! gem list vmfloaty | grep vmfloaty > /dev/null; then
   gem install vmfloaty
fi

host=$(floaty get centos-5-x86_64 | awk -F\" '{print $4}')
echo "$ME: building on $host"

ssh -o UserKnownHostsFile=/dev/null $host mkdir -p /usr/share/augeas/lenses/dist 2>/dev/null
scp -q  -o UserKnownHostsFile=/dev/null $(dirname $0)/augeas-base/* $host:/usr/share/augeas/lenses/dist/

ssh -o UserKnownHostsFile=/dev/null $host <<"END" 2>/dev/null
# Install build tools and libraries
rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-pc1-el-5.noarch.rpm
rpm -ivh http://pl-build-tools.delivery.puppetlabs.net/yum/el/5/x86_64/pl-build-tools-release-22.0.3-1.el5.noarch.rpm
yum update -y
yum -y install puppet-agent pl-boost pl-cmake pl-yaml-cpp pl-gcc zlib-devel libselinux-devel curl make pkgconfig openssl-devel curl-devel expat-devel
export PATH=/opt/pl-build-tools/bin:$PATH
export PKG_CONFIG_PATH=/opt/puppetlabs/puppet/lib/pkgconfig
export CMAKE="/opt/pl-build-tools/bin/cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/pl-build-toolchain.cmake -DCMAKE_PREFIX_PATH=/opt/pl-build-tools -DCMAKE_INSTALL_PREFIX=/opt/puppetlabs/puppet"
# Build Leatherman
cd ~
git clone --branch 0.10.1 https://github.com/puppetlabs/leatherman
mkdir -p leatherman/build
cd leatherman/build
${CMAKE} -DBOOST_STATIC=ON ..
make all install
# Build Libral
cd ~
git clone https://github.com/puppetlabs/libral
mkdir -p libral/build
cd libral/build
${CMAKE} -DLIBRAL_STATIC=ON ..
make
ln -s /etc/redhat-release /etc/system-release
../examples/dpack
END

echo "$ME: finished building on $host"

scp -o UserKnownHostsFile=/dev/null $host:/root/libral/build/ralsh-*.tgz .

floaty delete $host

exit 0
