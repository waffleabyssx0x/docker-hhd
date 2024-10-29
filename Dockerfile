FROM alpine as builder
ARG VERSION_HHD="v3.5.9"
ARG VERSION_ADJUSTOR="3.5.2"
EXPOSE 5335
WORKDIR /opt
RUN \
    # build deps
    apk add \
        # hhd deps
        git python3 py3-pip python3-dev musl-dev linux-headers gcc \
        # adjustor deps
        cairo-dev gobject-introspection-dev dbus dbus-dev fuse-dev && \
    # fetch source
    git clone --branch ${VERSION_HHD} https://github.com/hhd-dev/hhd && \
    rm -rf hhd\.git && \
    # build
    cd hhd && \
    python -m venv venv && \
    source venv/bin/activate && \
    pip install -e . && \
    pip3 install "adjustor==${VERSION_ADJUSTOR}"

FROM alpine as uibuilder
ARG VERSION_UI="v3.2.3"
WORKDIR /opt
RUN \
    # build deps
    apk add git npm && \
    # fetch source
    git clone --branch ${VERSION_UI} https://github.com/hhd-dev/hhd-ui && \
    # build
    cd hhd-ui && \
    npm ci && \
    npm run build_noerr

FROM alpine
RUN \
    # runtime deps
    apk add shadow python3 hidapi eudev fuse dbus-libs glib gobject-introspection musl-locales \
    # container runtime
    s6-overlay lighttpd socat patch
COPY --from=builder /opt/hhd/ /opt/hhd/
COPY --from=uibuilder /opt/hhd-ui/dist/ /opt/hhd-ui/
COPY ./lighttpd.conf /etc/lighttpd/
COPY ./services /services/
COPY patch* /opt/hhd/
WORKDIR /opt/hhd
EXPOSE 17000/tcp 5336/tcp
RUN \
    # patch source
    patch -p0 < patch001-disable-dnotify-function.patch && \
    apk del patch && \
    # s6 svc hhd
    install -Dm755 /services/hhd /etc/s6-overlay/s6-rc.d/hhd/run && \
    echo "longrun" > /etc/s6-overlay/s6-rc.d/hhd/type && \
    # s6 svc socat
    install -Dm755 /services/socat /etc/s6-overlay/s6-rc.d/socat/run && \
    echo "longrun" > /etc/s6-overlay/s6-rc.d/socat/type && \
    # s6 svc lighttpd
    install -Dm755 /services/lighttpd /etc/s6-overlay/s6-rc.d/lighttpd/run && \
    echo "longrun" > /etc/s6-overlay/s6-rc.d/lighttpd/type && \
    # s6
    mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d/ && \
    install -Dm600 /dev/null /etc/s6-overlay/s6-rc.d/user/contents.d/hhd && \
    install -Dm600 /dev/null /etc/s6-overlay/s6-rc.d/user/contents.d/lighttpd && \
    install -Dm600 /dev/null /etc/s6-overlay/s6-rc.d/user/contents.d/socat && \
    # cleanup
    rm -rf /services && \
    # user and grp
    addgroup hhd_grp && \
    adduser -D -G hhd_grp hhd && \
    mkdir -p /home/hhd/.config/hhd && \
    chown hhd:hhd_grp /home/hhd/.config/hhd && \
    chmod 770 /home/hhd/.config/hhd

ENTRYPOINT ["/init"]