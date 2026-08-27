#!/bin/bash

# install packages
apt-get update \
  && apt-get install -y \
    fd-find \
    fzf \
    git \
    jq \
    openssh-client \
    ripgrep

# Install yq (mikefarah/yq)
ARCH_RAW=$(uname -m)
case $ARCH_RAW in
  x86_64)
    ARCH="amd64"
    C_ARCH="x64"
    ;;
  aarch64)
    ARCH="arm64"
    C_ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: ${ARCH_RAW}"
    exit 1
    ;;
esac

# Install yq (mikefarah/yq)
YQ_VER=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r '.tag_name')
curl -Lo /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VER}/yq_linux_${ARCH}"
chmod +x /usr/local/bin/yq

# Install nushell
NU_DOWNLOAD=$( \
    curl -fsSL https://api.github.com/repos/nushell/nushell/releases/latest \
    | jq -r '.assets[] | select(.name | test("linux") and test("gnu") and test("'${ARCH_RAW}'")) | .browser_download_url'
)
curl -fsSL "${NU_DOWNLOAD}" | tar xz -C /tmp
chmod a+x /tmp/nu-*${ARCH_RAW}*linux*/nu*
mv /tmp/nu-*${ARCH_RAW}*linux*/nu* /usr/local/bin/

# Install node
NODE_VER=$(curl -s https://api.github.com/repos/nodejs/node/releases/latest | yq '.tag_name')
curl -fsSL "https://nodejs.org/download/release/latest/node-${NODE_VER}-linux-${C_ARCH}.tar.gz" | tar -xzC /tmp
chmod a+x "/tmp/node-${NODE_VER}-linux-${C_ARCH}/bin/"*
for d in "/tmp/node-${NODE_VER}-linux-${C_ARCH}/"*; do
    dir_name=${d##*/}
    if [ -d "${d}" ]; then
        [ ! -d "/usr/${dir_name}" ] && mkdir -p "/usr/${dir_name}"
        cp -f -r "${d}/"* "/usr/${dir_name}/"
    fi
done
rm -Rf "/tmp/node-${NODE_VER}-linux-${C_ARCH}"

# Clear apt cache
rm -rf /var/lib/apt/lists/*