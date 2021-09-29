ARG DIST
FROM docker.io/${DIST}:latest AS base

ARG DIST
RUN \
  if [ "$DIST" = 'alpine' ]; then \
    wget \
      https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-amd64.tar.gz \
      -O - | \
      tar -xz -C /; \
  elif [ "$DIST" = 'fedora' ]; then \
    echo noop; \
  else \
    exit 1; \
  fi

ARG DIST
RUN \
  if [ "$DIST" = 'alpine' ]; then \
    apk add --no-cache \
      iproute2 libvirt-qemu ovmf qemu-img qemu-modules qemu-system-x86_64 \
      virt-install mesa-dri-intel \
      dbus samba openssh \
      less rsync shadow; \
  elif [ "$DIST" = 'fedora' ]; then \
    dnf upgrade -y && \
    dnf install -y \
      # libvirt
      libvirt libvirt-daemon-qemu virt-install \
      # qemu and its optional features depends
      mesa-dri-drivers qemu samba \
      # systemd and container-init service depends
      less rsync socat systemd \
      # optional services
      cockpit-bridge cockpit-machines openssh-server && \
    rm -rf /run/* /var/{cache,lib}/dnf /var/log/*; \
  else \
    exit 1; \
  fi

RUN \
  for f in libvirt samba sasl2 ssh; do \
    mv /etc/${f} /etc/${f}.sample; \
    ln -s /config/${f} /etc/${f}; \
    done && \
  rm -r /var/lib/libvirt && ln -s /data /var/lib/libvirt && \
  rm -rf /var/log/libvirt && ln -s /log/libvirt /var/log/libvirt && \
  rm -rf /var/log/samba && ln -s /log/samba /var/log/samba && \
  rm -rf /var/log/swtpm && ln -s /log/swtpm /var/log/swtpm && \
  sed -i \
    -e 's/#\(auth_unix_rw = \)"polkit"/\1"none"/' \
    -e 's/#\(unix_sock_group =\).*/\1"libvirt_access"/' \
    -e 's/#\(unix_sock_ro_perms =\).*/\1"0660"/' \
    -e 's/#\(unix_sock_rw_perms =\).*/\1"0660"/' \
    /etc/libvirt.sample/libvirtd.conf && \
  # https://unix.stackexchange.com/a/193131
  usermod -p '*' root

# add local files
COPY root/ /

ARG DIST
COPY root.${DIST}/ /

# volumes
VOLUME /config
VOLUME /data
VOLUME /log

FROM base AS extra-alpine
ENTRYPOINT ["/init"]

FROM base AS extra-fedora
ENTRYPOINT ["/sbin/init"]
# gracefuly stop systemd
# https://bugzilla.redhat.com/show_bug.cgi?id=1201657
STOPSIGNAL RTMIN+3

ARG DIST
FROM extra-${DIST} AS finalize
