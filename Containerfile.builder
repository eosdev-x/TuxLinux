ARG SOURCE_IMAGE
ARG BIB_IMAGE=quay.io/centos-bootc/bootc-image-builder:latest
FROM ${SOURCE_IMAGE} AS source-keys
# BIB's dependency solver resolves file:// key URLs in the builder filesystem.
# Dereference source-image symlinks; retain the builder's other distro keys.
RUN mkdir /tmp/tuxlinux-rpm-gpg && cp -L /etc/pki/rpm-gpg/* /tmp/tuxlinux-rpm-gpg/
FROM ${BIB_IMAGE}
COPY --from=source-keys /tmp/tuxlinux-rpm-gpg/ /etc/pki/rpm-gpg/
