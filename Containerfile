FROM ghcr.io/void-linux/void-glibc-full:latest

RUN set -eu; \
    packages="bash git xorriso squashfs-tools dosfstools mtools e2fsprogs kmod"; \
    case "$(uname -m)" in aarch64) repo_suffix="/aarch64" ;; *) repo_suffix="" ;; esac; \
    case "$(uname -m)" in aarch64) packages="$packages qemu-user-amd64 binfmt-support" ;; esac; \
    for repo_base in \
        https://mirrors.summithq.com/voidlinux/current \
        https://repo-fastly.voidlinux.org/current \
        https://repo-de.voidlinux.org/current; do \
        repo="${repo_base}${repo_suffix}"; \
        rm -rf /var/cache/xbps/* /var/db/xbps/https_*; \
        mkdir -p /etc/xbps.d /var/lib/binfmts; \
        printf 'repository=%s\n' "$repo" > /etc/xbps.d/00-repository-main.conf; \
        if xbps-install -Sy && xbps-install -y $packages; then \
            exit 0; \
        fi; \
        sleep 2; \
    done; \
    echo "All Void Linux mirrors failed" >&2; \
    exit 1

WORKDIR /work

CMD ["/work/tools/build-iso.sh"]
