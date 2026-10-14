# Copyright 2026 Han Li and contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

# NOTE: no heredoc here. This Dockerfile is built through the daemon's
# classic `POST /build` endpoint via testcontainers-go
# (tests/e2e/linux/e2e_test.go), which does not understand `RUN <<EOF`
# heredocs and silently drops their body. The chained-`;` form below works
# on both the classic builder and BuildKit (`docker build`).
#
# libatomic1: current Node.js linux-x64 releases link libatomic.so.1, which
# the stock Ubuntu image does not carry.
RUN set -o errexit -o nounset -o xtrace; \
    apt-get update; \
    apt-get install --assume-yes \
        ca-certificates \
        curl \
        git \
        golang \
        libatomic1 \
        zip

COPY metadata.lua /e2e/metadata.lua
COPY hooks /e2e/hooks
COPY lib /e2e/lib

# Long-lived container: the Go test (e2e_test.go) drives every phase through
# exec calls, so the main process just idles here.
CMD ["sleep", "infinity"]
