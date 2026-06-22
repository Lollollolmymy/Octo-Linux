#!/bin/sh
set -eu

rootfs="${1:?rootfs path required}"

chroot_run() {
    chroot "$rootfs" /bin/sh -c "$*"
}

if ! chroot_run "id octo >/dev/null 2>&1"; then
    groups="wheel"
    for group in audio video input storage network plugdev autologin; do
        if chroot_run "getent group $group >/dev/null 2>&1"; then
            groups="$groups,$group"
        fi
    done

    chroot "$rootfs" useradd -m -s /bin/zsh -G "$groups" octo
fi

chroot_run "printf '%s\n' 'octo:octo' | chpasswd"

mkdir -p "$rootfs/etc/sudoers.d"
cat > "$rootfs/etc/sudoers.d/10-octolinux-wheel" <<'EOF'
%wheel ALL=(ALL:ALL) ALL
EOF
chmod 0440 "$rootfs/etc/sudoers.d/10-octolinux-wheel"

if ! grep -q '^/bin/zsh$' "$rootfs/etc/shells" 2>/dev/null; then
    printf '%s\n' /bin/zsh >> "$rootfs/etc/shells"
fi

mkdir -p "$rootfs/usr/share/octolinux"
cat > "$rootfs/usr/share/octolinux/stage" <<'EOF'
stage1-graphical
EOF

chmod +x \
    "$rootfs/usr/local/bin/octolinux-session" \
    "$rootfs/usr/local/bin/octolinux-installer" \
    "$rootfs/usr/local/bin/octofetch" \
    "$rootfs/usr/local/bin/octolinux-first-login" \
    "$rootfs/usr/local/sbin/octolinux-install-system" \
    "$rootfs/etc/sv/octolinux-graphical/run"
chmod 0755 "$rootfs/etc/skel/Desktop/install-octolinux.desktop"

ln -snf octofetch "$rootfs/usr/local/bin/neofetch"
ln -snf octofetch "$rootfs/usr/local/bin/nanofetch"

service_dir="$rootfs/etc/runit/runsvdir/default"
mkdir -p "$service_dir"
sed \
    -e 's/@@MKLIVE_VERSION@@/OctoLinux-stage1/g' \
    -e 's/Void Linux/OctoLinux/g' \
    -e 's|https://www\.voidlinux\.org|OctoLinux advanced installer|g' \
    -e 's/#voidlinux/#octolinux/g' \
    /work/void-mklive/installer.sh > "$rootfs/usr/bin/void-installer"
chmod 0755 "$rootfs/usr/bin/void-installer"

for service in dbus elogind NetworkManager lightdm octolinux-graphical; do
    if [ -d "$rootfs/etc/sv/$service" ]; then
        ln -snf "/etc/sv/$service" "$service_dir/$service"
    fi
done
rm -f "$service_dir/agetty-tty1" "$service_dir/dhcpcd" \
    "$service_dir/wpa_supplicant" "$service_dir/greetd"

mkdir -p "$rootfs/etc/pipewire/pipewire.conf.d"
ln -snf /usr/share/examples/wireplumber/10-wireplumber.conf \
    "$rootfs/etc/pipewire/pipewire.conf.d/10-wireplumber.conf"
ln -snf /usr/share/examples/pipewire/20-pipewire-pulse.conf \
    "$rootfs/etc/pipewire/pipewire.conf.d/20-pipewire-pulse.conf"
