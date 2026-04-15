/*
 * gemm_tiled.cu — Shared-memory tiled 1024x1024 FP32 GEMM (tile size = 8)
 * ECE 410/510 Spring 2026 | Yaqoub Rabiah | Codefest 3 CLLM
 *
 * Each thread block loads a TILE_SIZE x TILE_SIZE tile of A and B into shared
 * memory before computing. This reduces DRAM traffic by a factor of TILE_SIZE
 * compared to the naive kernel: each element is loaded from DRAM N/TILE_SIZE
 * times instead of N times.
 *
 * Compile:  nvcc -O2 -o gemm_tiled gemm_tiled.cu
 * Run:      ./gemm_tiled
 */

#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>

#define N         1024
#define TILE_SIZE 8
#define NUM_RUNS  10

/* ── Kernel ─────────────────────────────────────────────────────────────── */
__global__ void gemm_tiled_kernel(const float * __restrict__ A,
                                   const float * __restrict__ B,
                                   float *C, int n)
{
    /* Shared memory tiles for A and B */
    __shared__ float As[TILE_SIZE][TILE_SIZE];
    __shared__ float Bs[TILE_SIZE][TILE_SIZE];

    int row = blockIdx.y * TILE_SIZE + threadIdx.y;
    int col = blockIdx.x * TILE_SIZE + threadIdx.x;

    float sum = 0.0f;
    int num_tiles = (n + TILE_SIZE - 1) / TILE_SIZE;

    for (int t = 0; t < num_tiles; t++) {

        /* Load one tile of A from DRAM into shared memory */
        int a_col = t * TILE_SIZE + threadIdx.x;
        As[threadIdx.y][threadIdx.x] = (row < n && a_col < n)
                                       ? A[row * n + a_col]
                                       : 0.0f;

        /* Load one tile of B from DRAM into shared memory */
        int b_row = t * TILE_SIZE + threadIdx.y;
        Bs[threadIdx.y][threadIdx.x] = (b_row < n && col < n)
                                       ? B[b_row * n + col]
                                       : 0.0f;

        /* All threads in block must finish loading before computing */
        __syncthreads();

        /* Compute partial dot product using shared-memory tiles */
        for (int k = 0; k < TILE_SIZE; k++) {
            sum += As[threadIdx.y][k] * Bs[k][threadIdx.x];
        }

        /* Ensure all threads finish computing before loading next tile */
        __syncthreads();
    }

    if (row < n && col < n) {
        C[row * n + col] = sum;
    }
}

/* ── Host ───────────────────────────────────────────────────────────────── */
int main(void)
{
    printf("=== Tiled GEMM (N=%d, TILE_SIZE=%d) ===\n", N, TILE_SIZE);

    /* Print GPU info */
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    printf("GPU: %s\n", prop.name);
    printf("Peak mem BW: %.1f GB/s\n",
           2.0 * prop.memoryClockRate * (prop.memoryBusWidth / 8) / 1e6);

    size_t size = (size_t)N * N * sizeof(float);

    /* Allocate host memory */
    float *h_A = (float*)malloc(size);
    float *h_B = (float*)malloc(size);
    float *h_C = (float*)malloc(size);

    /* Initialise */
    for (int i = 0; i < N * N; i++) {
        h_A[i] = (float)(rand() % 100) / 100.0f;
        h_B[i] = (float)(rand() % 100) / 100.0f;
    }

    /* Allocate device memory */
    float *d_A, *d_B, *d_C;
    cudaMalloc(&d_A, size);
    cudaMalloc(&d_B, size);
    cudaMalloc(&d_C, size);

    cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, size, cudaMemcpyHostToDevice);

    dim3 threads(TILE_SIZE, TILE_SIZE);
    dim3 blocks((N + TILE_SIZE - 1) / TILE_SIZE,
                (N + TILE_SIZE - 1) / TILE_SIZE);

    /* Warm-up */
    gemm_tiled_kernel<<<blocks, threads>>>(d_A, d_B, d_C, N);
    cudaDeviceSynchronize();

    /* Timed runs */
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    for (int r = 0; r < NUM_RUNS; r++) {
        gemm_tiled_kernel<<<blocks, threads>>>(d_A, d_B, d_C, N);
    }
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float ms_total = 0.0f;
    cudaEventElapsedTime(&ms_total, start, stop);
    float ms_avg = ms_total / NUM_RUNS;

    /* FLOPs = 2 * N^3 */
    double flops  = 2.0 * (double)N * N * N;
    double gflops = flops / (ms_avg * 1e-3) / 1e9;

    /* Theoretical DRAM traffic with tiling: 2*N^3/TILE_SIZE + N^2 elements */
    double bytes_theory = (2.0 * N * N * N / TILE_SIZE + (double)N * N) * 4.0;
    double ai_theory    = flops / bytes_theory;

    printf("Avg time (%d runs): %.3f ms\n", NUM_RUNS, ms_avg);
    printf("Achieved:           %.2f GFLOP/s\n", gflops);
    printf("Theoretical AI:     %.4f FLOP/byte\n", ai_theory);
    printf("Roofline bound:     memory-bound (AI < ridge point, but closer than naive)\n");

    /* Speedup note */
    printf("Expected DRAM traffic reduction vs naive: %.1fx (= TILE_SIZE)\n",
           (double)TILE_SIZE);

    /* Copy result back */
    cudaMemcpy(h_C, d_C, size, cudaMemcpyDeviceToHost);
    printf("C[0][0] = %.6f  (non-zero sanity check)\n", h_C[0]);

    /* Cleanup */
    cudaFree(d_A); cudaFree(d_B); cudaFree(d_C);
    free(h_A); free(h_B); free(h_C);
    cudaEventDestroy(start); cudaEventDestroy(stop);

    return 0;
}
