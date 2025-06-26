FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS build

ARG LLAMA_CPP_TAG="b5753"


WORKDIR /srv

# install build tools and clone and compile llama.cpp
RUN \
  apt-get update && \
  apt-get install -y build-essential git libgomp1 cmake libcurl4-openssl-dev

# -DCMAKE_CUDA_ARCHITECTURES=86;89;120
RUN git clone --branch ${LLAMA_CPP_TAG} https://github.com/ggerganov/llama.cpp.git \
  && cd llama.cpp \
  && cmake -B build \
    -DGGML_CUDA=on \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_NATIVE=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--allow-shlib-undefined" \
    -DCMAKE_CUDA_ARCHITECTURES="86;89;90;100;120" \
  && cmake --build build --config Release -j


FROM debian:bookworm-slim
LABEL org.opencontainers.image.source=https://github.com/jspaulsen/llama-cpp-docker

RUN \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    ca-certificates \
    libgomp1 \
    libcurl4-openssl-dev

# copy openmp and cuda libraries
ENV LD_LIBRARY_PATH=/usr/local/lib
COPY --from=build /usr/lib/x86_64-linux-gnu/libgomp.so.1 ${LD_LIBRARY_PATH}/libgomp.so.1
COPY --from=build /usr/local/cuda-12.8/lib64/libcublas.so.12 ${LD_LIBRARY_PATH}/libcublas.so.12
COPY --from=build /usr/local/cuda-12.8/lib64/libcublasLt.so.12 ${LD_LIBRARY_PATH}/libcublasLt.so.12
COPY --from=build /usr/local/cuda-12.8/lib64/libcudart.so.12 ${LD_LIBRARY_PATH}/libcudart.so.12

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


ENTRYPOINT ["llama-server"]
