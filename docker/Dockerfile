# Dockerfile for Quantum-Safe gRPC PQC Microservices
# Base: Ubuntu 24.04; builds OpenSSL 3.5.5 and gRPC/Protobuf/Abseil, then the project.
# Use with docker-compose or CI; certs must be mounted at /PQC/certs at runtime.

FROM ubuntu:24.04

# Install build tools and dependencies (zlib1g-dev required by gRPC CMake; curl for install_grpc_deps.sh)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential cmake git perl wget curl ca-certificates zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Build and install OpenSSL 3.5.5 to /usr/local (same prefix as gRPC deps so install_grpc_deps.sh finds it).
# RPATH so the installed openssl binary and libs use /usr/local libs (for validate_tls.sh / s_client in image).
WORKDIR /tmp
RUN wget -q https://www.openssl.org/source/openssl-3.5.5.tar.gz && \
    tar xzf openssl-3.5.5.tar.gz && \
    cd openssl-3.5.5 && \
    LDFLAGS="-Wl,-rpath,/usr/local/lib64 -Wl,-rpath,/usr/local/lib" \
    ./Configure --prefix=/usr/local enable-unstable-qlog && \
    make -j$(nproc) && \
    make install && \
    echo '/usr/local/lib' > /etc/ld.so.conf.d/openssl-3.5.5.conf && \
    echo '/usr/local/lib64' >> /etc/ld.so.conf.d/openssl-3.5.5.conf && \
    ldconfig && \
    cd /tmp && rm -rf openssl-3.5.5 openssl-3.5.5.tar.gz

# Environment so CMake and gRPC build use OpenSSL 3.5.5
ENV OPENSSL_ROOT_DIR=/usr/local
ENV LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH:-}
ENV PATH=/usr/local/bin:${PATH}

# Copy project source (needed for install_grpc_deps.sh and later build)
WORKDIR /PQC
COPY . /PQC

# Install gRPC 1.75.1, Protobuf 31.1, Abseil 20250512.1 to /usr/local (uses OPENSSL_ROOT_DIR for gRPC)
RUN PREFIX=/usr/local bash /PQC/scripts/install_grpc_deps.sh

# Build project; keep build artifacts for runtime (docker-compose runs service_a/service_b from build/)
RUN cmake -B build -DCMAKE_PREFIX_PATH=/usr/local && \
    cmake --build build -j$(nproc)

# Default: run tests (CI can override with docker-compose or custom command)
CMD ["ctest", "--test-dir", "build", "--output-on-failure"]
