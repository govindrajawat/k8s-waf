# Multi-stage build for Kubernetes WAF with NGINX + ModSecurity
FROM ubuntu:22.04 as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpcre3-dev \
    libssl-dev \
    zlib1g-dev \
    libxml2-dev \
    libyajl-dev \
    libcurl4-openssl-dev \
    libgeoip-dev \
    liblmdb-dev \
    libpcre++-dev \
    libtool \
    autoconf \
    automake \
    wget \
    git \
    cmake \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Build ModSecurity
WORKDIR /tmp
RUN git clone --depth 1 -b v3.0.8 https://github.com/SpiderLabs/ModSecurity.git && \
    cd ModSecurity && \
    git submodule init && \
    git submodule update && \
    ./build.sh && \
    ./configure && \
    make && \
    make install

# Build ModSecurity-NGINX connector
RUN git clone --depth 1 -b v1.0.3 https://github.com/SpiderLabs/ModSecurity-nginx.git

# Build NGINX with ModSecurity
RUN wget https://nginx.org/download/nginx-1.24.0.tar.gz && \
    tar -xzf nginx-1.24.0.tar.gz && \
    cd nginx-1.24.0 && \
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-http_auth_request_module \
        --with-http_xslt_module \
        --with-http_image_filter_module \
        --with-http_geoip_module \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-stream_realip_module \
        --with-stream_geoip_module \
        --with-http_slice_module \
        --with-file-aio \
        --with-http_v2_module \
        --with-http_v3_module \
        --add-module=/tmp/ModSecurity-nginx && \
    make && \
    make install

# Runtime stage
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libpcre3 \
    libssl3 \
    zlib1g \
    libxml2 \
    libyajl2 \
    libcurl4 \
    libgeoip1 \
    liblmdb0 \
    ca-certificates \
    curl \
    wget \
    vim \
    htop \
    net-tools \
    iputils-ping \
    telnet \
    tcpdump \
    fail2ban \
    && rm -rf /var/lib/apt/lists/*

# Copy NGINX and ModSecurity from builder
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/local/include /usr/local/include

# Create necessary directories
RUN mkdir -p /var/cache/nginx /var/log/nginx /var/run /etc/nginx/conf.d /etc/nginx/modsecurity

# Copy configuration files
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY config/modsecurity/modsecurity.conf /etc/nginx/modsecurity/modsecurity.conf
COPY config/modsecurity/crs-setup.conf /etc/nginx/modsecurity/crs-setup.conf
COPY config/modsecurity/rules/ /etc/nginx/modsecurity/rules/

# Copy scripts
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/healthcheck.sh /healthcheck.sh
COPY scripts/fail2ban-setup.sh /fail2ban-setup.sh

# Set permissions
RUN chmod +x /entrypoint.sh /healthcheck.sh /fail2ban-setup.sh && \
    chown -R www-data:www-data /var/cache/nginx /var/log/nginx

# Create symlinks for library loading
RUN ldconfig

# Expose ports
EXPOSE 80 443 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /healthcheck.sh

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
