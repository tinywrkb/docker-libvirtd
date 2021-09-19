# docker-libvirtd

## todo
* ssh-keygen on alpine
* systemd: change entrypoint to /init without breaking the container
* move systemd masking to dockerfile?
* evaluate if sock cleanup is still needed now that the systemd service dependency cycle is fixed, and add it to s6
* validate
  * samba in vm
  * tcp libvirt access
  * virtiofs host's daemon
    * maybe rootless can work with the rust daemon? from flatpak?
    * probably need access to /dev/shm if using file-backed memory
    * maybe need access to /dev/hugepages if using hugepage-backed memory
* alpine
  * package cockpit-bridge & cockpit-machines
  * read-only rootfs
  * host pid namespace
  * usb access, might need udev
  * evaluate if libvirt-dbus and a running dbus session are needed, optionally disable dbus with envvar
* fedora
  * add networkmanager & cockpit-networkmanager?
* samba
  * default shares with host when running with a private network namespace, /data /config
  * nmbd service
* modes: document, build, run, and validate
  * [x] rootful, local unix socket
  * [ ] rootful, host network namespace
  * [ ] rootful, private network namespace
    * dedicated bridge in the namespace
    * optionally access host's bridge directly
    * allow accessing vms from the host, and from host's network
  * [ ] rootful, privileged, currently breaks host
  * [ ] rootful, host pid namespace with polkit
    * with private pid namespace there's no auth, just using gid memebership
    * probably only in alpine, can't use systemd
    * pid namespace breaks polkit
    * enable polkit proxy auth, user config setting, just document this
    * set back socket mode
    * service to create users
    * created users in the container should belog to libvirt?
  * [ ] rootless, local unix socket
  * [ ] rootless, host network namespace
  * [ ] rootless, private host network namespace? can this work?
  * [ ] rootless, host pid namespace with polkit? can this work?
* document
  * handle unix socket mount and permission access, polkit doesn't work
  * ssh access and setup
  * sasl auth with scram-sha-256 for unix socket, https://libvirt.org/auth.html#sasl-pluggable-authentication
  * cockpit-machines
  * systemd service with a dynamic user for rootless pod with podman-compose
    * need to handle socket permissions differently
  * not supported mode: running services as a non-root user in the container
  * mounting into the container with nsenter, https://jpetazzo.github.io/2015/01/13/docker-mount-dynamic-volumes/

## issues
* usb access: missing udev properties
  * log: `libvirtd: internal error: Missing udev property 'ID_VENDOR_ID' on 'usb'`
  * solution1: mask /sys/bus/usb by mounting an empty volume
  * solution2:
    * bind mount /run/udev to give access to the host's udev database
    * bind mount /dev/bus/usb might also be needed
* libcap-ng file capabilities
  * log: `libvirtd: libcap-ng used by "/usr/sbin/libvirtd" failed due to not having CAP_SETPCAP in capng_apply`
  * possible workaround: `setcap cap_setpcap+eip /usr/lib64/libcap-ng.so.0`, edit: doesn't work
  * permanent solution: might be fixed in upstream, https://bugzilla.redhat.com/show_bug.cgi?id=1924218
* /run/libvirt cleanup related
  * log: `libvirtd: failed to connect to monitor socket: Connection refused`
  * reason:
    * client is trying too early to connect?
    * libvirt's qemu monitor socket is missing? maybe due removal of /run/libvirt, or somewhere else? /run/systemd/machines?
    * is there's something left in /var/lib/libvirt/qemu?
  * possible workaround: don't clean everything in /run/libvirt, only remove libvirt-sock{,-ro}
* stateful related
  * log: `virtlogd: Unable to open file: /var/log/libvirt/qemu/<VIRTUAL_MACHINE>.log: No such file or directory`
  * workaround: add /var/log or /var/log/libvirt volume
* vm shutdown error
  * log: `libvirtd: internal error: End of file from qemu monitor`
* polkit socket auth broken
  * reason: container has a private pid namespace
  * workaround: switch to non systemd init, and allow host pid namespace
  * note: user has to be in the libvirt, and socket mode should be 0666
* cockpit-machines with host's cockpit session
  * host issues
    * can't add ssh keys
    * known_hosts that needed for remote cockpit-bridge login is saved in /root, need a different location for this
  * cockpit-machines issues
    * spice display is not available, vm should have vnc enabled
    * black screen with vnc when virgl 3d is enabled, can only work locally
* networking
  * host's bridge access
    * log: `libvirtd: Cannot get interface MTU on 'br0': No such device`
    * solution: use host's network namespace
  * containers bridge device
    * log: `libvirtd: cannot write to '/proc/sys/net/ipv6/conf/virbr0/disable_ipv6' on bridge 'virbr0': Read-only file system`
    * workaround: ?
* systemd
  * login related services starting
    * log: `systemd: Failed to enqueue kbrequest.target job: Unit kbrequest.target not found.`
    * possible workaround: mask services like: systemd-logind.service, getty.target, getty@.service
  * device mapper and loop device related errors
    * log: `systemd: Couldn't stat device /dev/mapper/control: No such file or directory`
    * log: `systemd: Couldn't stat device /dev/loop-control: No such file or directory`
    * workaround: mask systemd-homed.service
  * systemd doesn't respect environment vars
    * workaround1: add `systemd.setenv=VAR=VALUE` to `CMD []` in `Dockerfile` (default values), and/or `command: []` in `compose.yaml` (overrides)
    * workaround2: add `PassEnvironment=VAR1 VAR2...` to systemd service, see `systemd.exec` man page
    * workaround3: add an initialization service, use `PassEnvironment` for the service, and update environment with `systemctl set-environment`
  * shutdown: systemd tries to unmount targets mounted by podman and fails
    * log: `Failed unmounting /config` `Failed unmounting Temporary Directory /tmp` ...
