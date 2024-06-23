FROM golang:1.22 AS builder

ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH:-"amd64"}
ARG GOPROXY
ENV GOPROXY=${GOPROXY:-"https://proxy.golang.org,direct"}
ARG JUICEFS_CE_VERSION
ENV JUICEFS_CE_VERSION=${JUICEFS_CE_VERSION:-"1.1.3"}

WORKDIR /docker-volume-juicefs
COPY . .
RUN echo "deb http://deb.debian.org/debian bookworm-backports main" | tee -a /etc/apt/sources.list && \
    apt-get update && apt-get install -y curl musl-tools tar gzip upx-ucl/bookworm-backports libc6 libc6-dev && \
    CC=/usr/bin/musl-gcc go build -o bin/docker-volume-juicefs --ldflags '-linkmode external -extldflags "-static"' .

WORKDIR /workspace
RUN curl -fsSL -o juicefs-ce.tar.gz https://github.com/juicedata/juicefs/releases/download/v${JUICEFS_CE_VERSION}/juicefs-${JUICEFS_CE_VERSION}-linux-${TARGETARCH}.tar.gz && \
    tar -zxf juicefs-ce.tar.gz -C /tmp && \
    # curl -fsSL -o /juicefs https://s.juicefs.com/static/juicefs && \
    chmod +x /tmp/juicefs

FROM python:3-alpine AS runner

RUN mkdir -p /run/docker/plugins /jfs/state /jfs/volumes
COPY --from=builder /docker-volume-juicefs/bin/docker-volume-juicefs /
COPY --from=builder /tmp/juicefs /bin/
# COPY --from=builder /juicefs /usr/bin/

RUN apk add libc6-compat
RUN /bin/juicefs --version
CMD ["docker-volume-juicefs"]
