ARG PG_BASE_IMAGE=postgres:17-bookworm

FROM ${PG_BASE_IMAGE} AS pg
ARG INSTALL_PG18=true
ENV DEBIAN_FRONTEND=noninteractive
RUN set -eux; \
    mkdir -p /etc/postgresql-common/createcluster.d; \
    echo 'create_main_cluster = false' > /etc/postgresql-common/createcluster.d/lab.conf; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        postgresql-17 postgresql-17-repmgr postgresql-17-cron postgresql-17-repack postgresql-17-credcheck \
        pgbackrest openssh-server openssh-client socat openssl tini cron procps iproute2 iputils-ping less gosu; \
    if [ "$INSTALL_PG18" = "true" ]; then \
        apt-get install -y --no-install-recommends postgresql-18; \
        for p in postgresql-18-repmgr postgresql-18-cron postgresql-18-repack postgresql-18-credcheck; do \
            apt-get install -y --no-install-recommends "$p" || echo "WARNING: $p is not available; lab upgrade check will report it"; \
        done; \
    fi; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /etc/lab /etc/repmgr /etc/pgbackrest /etc/pg-tls /var/log/repmgr /var/log/pgbackrest /var/log/postgresql \
             /var/spool/pgbackrest /var/lib/pgbackrest /var/lib/pgbackrest-verify /run/repmgr /run/postgresql /run/sshd /lab; \
    chown -R postgres:postgres /etc/repmgr /etc/pgbackrest /etc/pg-tls /var/log/repmgr /var/log/pgbackrest \
             /var/log/postgresql /var/spool/pgbackrest /var/lib/pgbackrest /var/lib/pgbackrest-verify /run/repmgr /run/postgresql; \
    usermod -s /bin/bash postgres
COPY node/conf/ /etc/lab/
COPY node/sql/ /etc/lab/sql/
COPY node/bin/ /usr/local/bin/
RUN chmod 0755 /usr/local/bin/*
ENV PGDATA=/var/lib/postgresql/data/pgdata \
    PATH=/usr/local/bin:/usr/lib/postgresql/17/bin:$PATH
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/lab-entrypoint"]

FROM pg AS runner
ARG K6_VERSION=1.3.0
ARG DOCKER_CLI_VERSION=28.5.1
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends python3 jq curl ca-certificates xz-utils; \
    rm -rf /var/lib/apt/lists/*; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in amd64) darch=x86_64 ;; arm64) darch=aarch64 ;; *) echo "unsupported $arch"; exit 1 ;; esac; \
    curl -fsSL "https://github.com/grafana/k6/releases/download/v${K6_VERSION}/k6-v${K6_VERSION}-linux-${arch}.tar.gz" \
        | tar -xz --strip-components=1 -C /usr/local/bin "k6-v${K6_VERSION}-linux-${arch}/k6"; \
    curl -fsSL "https://download.docker.com/linux/static/stable/${darch}/docker-${DOCKER_CLI_VERSION}.tgz" \
        | tar -xz --strip-components=1 -C /usr/local/bin docker/docker; \
    k6 version; docker --version
COPY runner/ /lab/runner/
COPY scenarios/ /lab/scenarios/
COPY experiments/ /lab/experiments/
COPY measure/ /lab/measure/
COPY backup/ /lab/backup/
COPY security/ /lab/security/
COPY maintenance/ /lab/maintenance/
COPY upgrade/ /lab/upgrade/
RUN find /lab -name '*.sh' -exec chmod 0755 {} + && chmod 0755 /lab/runner/bin/*
ENV PATH=/lab/runner/bin:/usr/local/bin:/usr/lib/postgresql/17/bin:$PATH
WORKDIR /lab
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/lab/runner/bin/lab"]
