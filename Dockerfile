FROM fedora:34 AS build

# Build ganesha from source, install it to /usr/local and a use multi stage build to have a smaller image
# Set NFS_V4_RECOV_ROOT to /export

RUN dnf install -y tar gcc cmake autoconf libtool bison flex make gcc-c++ krb5-devel dbus-devel jemalloc-devel libnfsidmap-devel libnsl2-devel userspace-rcu-devel patch libblkid-devel
RUN curl -L https://github.com/nfs-ganesha/nfs-ganesha/archive/V3.5.tar.gz | tar zx \
	  && curl -L https://github.com/nfs-ganesha/ntirpc/archive/v3.4.tar.gz | tar zx \
	  && rm -r nfs-ganesha-3.5/src/libntirpc \
	  && mv ntirpc-3.4 nfs-ganesha-3.5/src/libntirpc
WORKDIR /nfs-ganesha-3.5
RUN mkdir -p /usr/local \
    && cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_CONFIG=vfs_only -DCMAKE_INSTALL_PREFIX=/usr/local src/ \
    && sed -i 's|@SYSSTATEDIR@/lib/nfs/ganesha|/export|' src/include/config-h.in.cmake \
	  && make \
	  && make install
RUN mkdir -p /ganesha-extra \
    && mkdir -p /ganesha-extra/etc/dbus-1/system.d \
    && cp src/scripts/ganeshactl/org.ganesha.nfsd.conf /ganesha-extra/etc/dbus-1/system.d/

FROM registry.fedoraproject.org/fedora-minimal:34 AS run
RUN microdnf install -y libblkid userspace-rcu dbus-x11 rpcbind hostname nfs-utils xfsprogs jemalloc libnfsidmap && microdnf clean all

RUN mkdir -p /var/run/dbus \
    && mkdir -p /export

# add libs from /usr/local/lib64
RUN echo /usr/local/lib64 > /etc/ld.so.conf.d/local_libs.conf

# do not ask systemd for user IDs or groups (slows down dbus-daemon start)
RUN sed -i s/systemd// /etc/nsswitch.conf

COPY --from=build /usr/local /usr/local/
COPY --from=build /ganesha-extra /

RUN mkdir -p /etc/ganesha
COPY start.sh /

# run ldconfig after libs have been copied
RUN ldconfig

# expose mountd 20048/tcp and nfsd 2049/tcp and rpcbind 111/tcp 111/udp
EXPOSE 2049/tcp 20048/tcp 111/tcp 111/udp

ENTRYPOINT ["/start.sh"]