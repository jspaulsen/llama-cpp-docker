ARG CUDA_VERSION=12.8.0
ARG UBUNTU_VERSION=22.04

# Derived from https://github.com/ggml-org/llama.cpp/blob/master/.devops/cuda.Dockerfile#L21
ARG BASE_CUDA_DEV_CONTAINER=nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION}
ARG BASE_CUDA_RUN_CONTAINER=nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}


# build
FROM ${BASE_CUDA_DEV_CONTAINER} AS build

ARG LLAMA_CPP_TAG="b6337"
ARG CUDA_DOCKER_ARCH=default


WORKDIR /srv

# install build tools and clone and compile llama.cpp
RUN \
  apt-get update && \
  apt-get install -y \
    build-essential \
    git \
    libgomp1 \
    cmake \
    libcurl4-openssl-dev


RUN \
  git clone --branch ${LLAMA_CPP_TAG} https://github.com/ggerganov/llama.cpp.git && \
  cd llama.cpp && \
  # Set CUDA architecture
  if [ "${CUDA_DOCKER_ARCH}" != "default" ]; then \
    export CMAKE_ARGS="-DCMAKE_CUDA_ARCHITECTURES=${CUDA_DOCKER_ARCH}"; \
  fi && \
  # Build
  cmake -B build \
    -DGGML_NATIVE=OFF \
    -DGGML_CUDA=ON \
    -DGGML_BACKEND_DL=ON \
    -DGGML_CPU_ALL_VARIANTS=ON \
    -DLLAMA_BUILD_TESTS=OFF ${CMAKE_ARGS} -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined . && \
  cmake --build build --config Release -j$(nproc)


RUN \
  mkdir -p /srv/lib && \
  cd llama.cpp && \
  find build -name "*.so" -exec cp {} /srv/lib \;


# runtime
FROM ${BASE_CUDA_RUN_CONTAINER}

RUN \
  apt-get update && \
  apt-get install -y libgomp1 curl && \
  apt autoremove -y && \
  apt clean -y && \
  rm -rf /tmp/* /var/tmp/* && \
  find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete && \
  find /var/cache -type f -delete


# Copy libaries from llama.cpp to the runtime image
COPY --from=build /srv/lib /usr/local/lib

# Set LD_LIBRARY_PATH to include /usr/local/lib
ENV LD_LIBRARY_PATH=/usr/local/lib


# copy llama.cpp binaries
COPY --from=build /srv/llama.cpp/build/bin/llama-cli /usr/local/bin/llama-cli
COPY --from=build /srv/llama.cpp/build/bin/llama-server /usr/local/bin/llama-server

# create llama user and set home directory
RUN useradd \
  --system \
  --create-home \
  -u 1000 \
  llama

USER llama
WORKDIR /home/llama

EXPOSE 8080


ENV LD_LIBRARY_PATH=/usr/local/lib
ENTRYPOINT ["llama-server"]
