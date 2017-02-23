FROM alpine:3.4

MAINTAINER PIERRE KIRCHER <pkircher@me.com>

ENV LUA_VERSION 5.1
ENV TENGINE_VERSION 2.2.0
ENV VTS_VERSION v0.1.12

ENV LUA_PACKAGE lua${LUA_VERSION}
ENV TENGINE_PACKAGE tengine-${TENGINE_VERSION}

RUN apk --update add \
    build-base \
    wget \
    curl \
    git \
    lua \
    ${LUA_PACKAGE} \
    ${LUA_PACKAGE}-dev \
    libxslt-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    libc-dev \
    libpng-dev \
    openssl-dev \
    pcre-dev \
    jemalloc-dev \
    zlib-dev \
    linux-headers 

ENV CONFIG "\
    --user=nginx \
    --group=nginx \
    --with-file-aio \
    --with-ipv6 \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_slice_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_concat_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_degradation_module \
    --add-module=/tmp/nginx-module-vts \
    --with-http_sysguard_module \
    --with-http_dyups_module \
    --with-http_lua_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-jemalloc \
" 

RUN \
addgroup -S nginx \
&& adduser -D -S -h /usr/local/nginx -s /sbin/nologin -G nginx nginx 

RUN apk add lua

RUN cd /tmp \
    && git clone git://github.com/vozlt/nginx-module-vts.git \
    && cd nginx-module-vts \
    && git fetch --all --tags --prune \
    && git checkout tags/${VTS_VERSION}

RUN cd /tmp \
    && git clone https://github.com/keplerproject/luarocks.git \
    && cd luarocks \
    && sh ./configure \
    && make build install \
    && cd \
    && rm -rf /tmp/luarocks

RUN cd /tmp \
    && git clone https://github.com/alibaba/tengine.git \
    && cd tengine \
    && git fetch --all --tags --prune \
    && git checkout tags/${TENGINE_PACKAGE}

RUN cd /tmp/tengine \
    && sh ./configure $CONFIG --with-debug  \
    && make \
    && mv objs/nginx objs/nginx-debug \
    && sh ./configure $CONFIG \
    && make \
    && make install \
    && install -m755 objs/nginx-debug /usr/local/nginx/sbin/nginx-debug
RUN strip /usr/local/nginx/sbin/nginx* \
    && runDeps="$( \
scanelf --needed --nobanner /usr/local/nginx/sbin/nginx \
| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
| sort -u \
| xargs -r apk info --installed \
| sort -u \
)" \

&& ln -sf /dev/stdout /usr/local/nginx/logs/access.log \
&& ln -sf /dev/stderr /usr/local/nginx/logs/error.log 

COPY nginx.conf /usr/local/nginx/conf/nginx.conf
COPY nginx.vh.default.conf /usr/local/nginx/conf/conf.d/default.conf 

EXPOSE 80 443 

CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]