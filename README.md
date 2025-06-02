# Llama.cpp in Docker

Run [llama.cpp](https://github.com/ggerganov/llama.cpp) in a GPU accelerated
Docker container.

## Options

Options are specified as environment variables in the `docker-compose.yml` file.
By default, the following options are set:

* `GGML_CUDA_NO_PINNED`: Disable pinned memory for compatability (default is 1)
* `LLAMA_ARG_CTX_SIZE`: The context size to use (default is 2048)
* `LLAMA_ARG_N_GPU_LAYERS`: The number of layers to run on the GPU (default is 99)

See the [llama.cpp documentation](https://github.com/ggerganov/llama.cpp/tree/master/examples/server)
for the complete list of server options.
