# Build Dependencies

This project uses **system-installed** gRPC, Protobuf, and Abseil (no FetchContent). The root `CMakeLists.txt` expects these exact versions via `find_package()`.

## Required versions

| Package   | Version    | Source / archive |
|-----------|------------|------------------|
| **gRPC**  | 1.75.1     | https://github.com/grpc/grpc/archive/refs/tags/v1.75.1.tar.gz (use **git clone** with submodules; tarball omits `third_party`) |
| **Protobuf** | 31.1    | https://github.com/protocolbuffers/protobuf/releases/download/v31.1/protobuf-31.1.tar.gz |
| **Abseil** | 20250512.1 | https://github.com/abseil/abseil-cpp/releases/download/20250512.1/abseil-cpp-20250512.1.tar.gz |
| **OpenSSL** | ≥ 3.5.5 | System or custom install; see below and `cmake/FindOpenSSL35.cmake`. |

Abseil 20250512.1 is required for gRPC 1.75.1 compatibility.

## Installing dependencies

### OpenSSL 3.5.5+ (required first)

The gRPC install script requires OpenSSL ≥ 3.5.5. Many systems ship an older OpenSSL; install 3.5.5+ to a prefix, then run the gRPC script with the same prefix.

- **User install** (no root; recommended):
  ```bash
  PREFIX=$HOME/.local bash scripts/install_openssl.sh
  ```
  Then set your environment so this OpenSSL is used (add to `~/.bashrc` if you like):
  ```bash
  export PATH="$HOME/.local/bin:$PATH"
  export LD_LIBRARY_PATH="$HOME/.local/lib:$HOME/.local/lib64:${LD_LIBRARY_PATH:-}"
  ```
  Verify: `openssl version` should show OpenSSL 3.5.5 or newer.

- **System-wide**: `sudo bash scripts/install_openssl.sh` (installs to `/usr/local`).

When you run `install_grpc_deps.sh`, it checks `PREFIX` first for OpenSSL, so use the same `PREFIX` (e.g. `PREFIX=$HOME/.local`) for both scripts.

- OpenSSL install script: `scripts/install_openssl.sh`

### gRPC, Protobuf, Abseil (automated install)

Use the project script to build and install in the correct order (Abseil → Protobuf → gRPC):

- **System-wide** (requires root):
  ```bash
  sudo bash scripts/install_grpc_deps.sh
  ```
  This also removes incompatible apt packages (e.g. older `libgrpc-dev`, `libprotobuf-dev`).

- **Custom prefix** (no root):
  ```bash
  PREFIX=$HOME/.local bash scripts/install_grpc_deps.sh
  ```
  Then configure the project with:
  ```bash
  cmake -B build -DCMAKE_PREFIX_PATH=$HOME/.local
  ```

**Note — broken libssl.so.3:** If you see `libssl.so.3: cannot open shared object file`, sudo will not work (it depends on libssl). You must restore the library as root **without** using sudo:

- **If you have the root password:** run `su -` (not `sudo su -`), enter the root password, then:
  ```bash
  cp -a /lib/x86_64-linux-gnu/libssl.so.3.bak /lib/x86_64-linux-gnu/libssl.so.3
  cp -a /usr/lib/x86_64-linux-gnu/libssl.so.3.bak /usr/lib/x86_64-linux-gnu/libssl.so.3
  ldconfig
  exit
  ```
- **Otherwise:** boot into a root shell (e.g. GRUB: add `init=/bin/bash` to the kernel line, then `mount -o remount,rw /` and run the same `cp` and `ldconfig` commands), or use a live USB to copy the file on the system partition. Then reboot and use sudo as usual.

### Manual install order

1. **Abseil 20250512.1** — build and install to your prefix (e.g. `/usr/local`).
2. **Protobuf 31.1** — build with `CMAKE_PREFIX_PATH` set to the Abseil install prefix and `protobuf_ABSL_PROVIDER=package`; install to the same prefix.
3. **gRPC 1.75.1** — clone with submodules (`git clone --branch v1.75.1` then `git submodule update --init --recursive`), configure with `CMAKE_PREFIX_PATH` and:
   - `gRPC_PROTOBUF_PROVIDER=package`
   - `gRPC_ABSL_PROVIDER=package`
   - `gRPC_SSL_PROVIDER=package`
   - `gRPC_ZLIB_PROVIDER=package`
   - `gRPC_CARES_PROVIDER=module`
   - `gRPC_RE2_PROVIDER=module`  
   Then build and install.

gRPC cannot be built from the release tarball alone because it does not include `third_party` (c-ares, re2, etc.); use the git repository and submodules.

## CMake usage

- Root `CMakeLists.txt` uses **CONFIG** for Protobuf and Abseil, and finds **OpenSSL first** (so gRPC can resolve `OpenSSL::SSL`):
  - `find_package(OpenSSL 3.5 REQUIRED)` then `find_package(OpenSSL35 REQUIRED)`
  - `find_package(Protobuf CONFIG REQUIRED)` (do not use FindProtobuf module; it misreports version for 31.x)
  - `find_package(absl CONFIG REQUIRED)` (Abseil is installed as `absl`, not `abseil-cpp`)
  - `find_package(gRPC 1.75.1 REQUIRED)`
- If dependencies are not in a default path, set `CMAKE_PREFIX_PATH` to the install prefix (e.g. `-DCMAKE_PREFIX_PATH=/usr/local` or `$HOME/.local`).
- **For subagents / automated builds:** Full build and implementation notes (proto generation, TLS API, tests, exact env and commands) are in **`tasks/tasks-quantum-safe-grpc-pqc.md`** under **"Build and implementation notes (for subagents)"**. Use the same `LD_LIBRARY_PATH`, `PKG_CONFIG_PATH`, and `PATH` when configuring and building.

## Running validation scripts with OpenSSL 3.5.5

The TLS validation script (`scripts/validate_tls.sh`) and `scripts/tls_groups_check.sh` require OpenSSL ≥ 3.5. If your default `openssl` is older (e.g. 3.0.x), set **PREFIX** to your OpenSSL 3.5.5 install so the scripts and ServiceA use it:

- **System install:** `PREFIX=/usr/local bash scripts/validate_tls.sh`
- **User install:** `PREFIX=$HOME/.local bash scripts/validate_tls.sh`

Use the same `PREFIX` (and `LD_LIBRARY_PATH`/`PATH`) as for building; see BUILD.md.

## References

- OpenSSL install script: `scripts/install_openssl.sh`
- gRPC/Protobuf/Abseil install script: `scripts/install_grpc_deps.sh`
- Root CMake: `CMakeLists.txt` (comment block lists versions and sources)
- OpenSSL find module: `cmake/FindOpenSSL35.cmake`
