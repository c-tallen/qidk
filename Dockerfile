# syntax=docker/dockerfile:1
ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION} AS base

# Use bash+pipefail for RUN steps
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# 1. Add LLVM 14 repo
RUN apt-get update \
 && apt-get install -y --no-install-recommends wget gnupg lsb-release ca-certificates \
 && wget -qO - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - \
 && echo "deb http://apt.llvm.org/$(lsb_release -cs)/ llvm-toolchain-$(lsb_release -cs)-14 main" \
      > /etc/apt/sources.list.d/llvm-14.list \
 && rm -rf /var/lib/apt/lists/*

# 2. Core toolchain + deps
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      sudo build-essential clang-14 lld-14 cmake ninja-build git unzip zip wget curl \
      pkg-config python3 python3-pip python3-venv python3-dev \
      openjdk-11-jdk android-tools-adb \
      libprotobuf-dev protobuf-compiler libssl-dev libffi-dev libtool autoconf automake \
      libunwind-14-dev ca-certificates \
      libglib2.0-dev \
      libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgstreamer-plugins-good1.0-dev \
      gstreamer1.0-tools gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
      gstreamer1.0-plugins-ugly gstreamer1.0-libav \
      nlohmann-json3-dev libc++-dev libc++abi-dev \
      libgstrtspserver-1.0-dev \
      clang-format clang-tidy cppcheck \ 
      libopencv-dev python3-opencv \
      libcxxopts-dev libtesseract-dev tesseract-ocr \
      gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu \
      libcairo2-dev libgirepository1.0-dev \
      ssh \
 && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    libunwind-dev \
 && rm -rf /var/lib/apt/lists/*

# 3. Create non-root vscode user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
RUN groupadd --gid ${USER_GID} ${USERNAME} \
 && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME}

# 4. Python tooling
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel \
 && pip3 install --no-cache-dir numpy onnx onnxruntime packaging matplotlib

# 5. Download QAIRT SDK
ARG QAIRT_VERSION=2.34.0.250424
ARG QAIRT_URL="https://softwarecenter.qualcomm.com/api/download/software/sdks/Qualcomm_AI_Runtime_Community/All/${QAIRT_VERSION}/v${QAIRT_VERSION}.zip"
RUN curl -fsSL --retry 5 -o /tmp/qairt.zip "${QAIRT_URL}"

# 6. Install QAIRT via heredoc script
RUN mkdir -p /usr/local/bin \
 && tee /usr/local/bin/install_qairt.sh <<-'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f /tmp/qairt.zip ]]; then
  echo "[!] /tmp/qairt.zip not found; skipping QAIRT install."
  exit 0
fi

echo "[+] Installing QAIRT from /tmp/qairt.zip"
TMPDIR=$(mktemp -d)
unzip -q /tmp/qairt.zip -d "$TMPDIR"

EXTRACTED=$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d | head -n1)
if [[ -z "$EXTRACTED" ]] || [[ ! -d "$EXTRACTED" ]]; then
  echo "[-] No extracted directory!" >&2
  rm -rf "$TMPDIR"
  exit 1
fi

rm -rf /opt/qairt
mv "$EXTRACTED" /opt/qairt
rm -rf "$TMPDIR" /tmp/qairt.zip

cat << 'EOP' > /etc/profile.d/qairt.sh
export QAIRT_ROOT=/opt/qairt
source "$QAIRT_ROOT/bin/envsetup.sh"
EOP
chmod +x /etc/profile.d/qairt.sh

# (Skip dependency‐checker at build time; run it at container startup if you need.)
EOF

# Make installer executable and run it
RUN chmod +x /usr/local/bin/install_qairt.sh \
 && /usr/local/bin/install_qairt.sh

# 7. Ensure /bin/sh is executable and symlink to bash
RUN chmod a+rx /bin/sh \
 && ln -sf /bin/bash /bin/sh

# 8. Expose QAIRT and default to bash
ENV QAIRT_ROOT=/opt/qairt
ENV PATH="${QAIRT_ROOT}/bin:${PATH}"
ENV SHELL=/bin/bash

# 9. Final workspace & user
WORKDIR /workspace
USER ${USERNAME}
