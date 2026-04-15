/*
 * gemm_naive.cu — Naive 1024x1024 FP32 GEMM
 * ECE 410/510 Spring 2026 | Yaqoub Rabiah | Codefest 3 CLLM
 *
 * One thread per output element. No shared memory or data reuse.
 * Each thread independently loads a full row of A and full column of B from DRAM.
 *
 * Compile:  nvcc -O2 -o gemm_naive gemm_naive.cu
 * Run:      ./gemm_naive
 */

#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>

#define N 1024
#define BLOCK_DIM 16
#define NUM_RUNS 10

/* ── Kernel ─────────────────────────────────────────────────────────────── */
__global__ void gemm_naive_kernel(const float * __restrict__ A,
                                   const float * __restrict__ B,
                                   float *C, int n)
{
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (row < n && col < n) {
        float sum = 0.0f;
        for (int k = 0; k < n; k++) {
            sum += A[row * n + k] * B[k * n + col];
        }
        C[row * n + col] = sum;
    }
}

/* ── Host ───────────────────────────────────────────────────────────────── */
int main(void)
{
    printf("=== Naive GEMM (N=%d) ===\n", N);

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

    /* Initialise with small values */
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

    dim3 threads(BLOCK_DIM, BLOCK_DIM);
    dim3 blocks((N + BLOCK_DIM - 1) / BLOCK_DIM,
                (N + BLOCK_DIM - 1) / BLOCK_DIM);

    /* Warm-up */
    gemm_naive_kernel<<<blocks, threads>>>(d_A, d_B, d_C, N);
    cudaDeviceSynchronize();

    /* Timed runs */
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    for (int r = 0; r < NUM_RUNS; r++) {
        gemm_naive_kernel<<<blocks, threads>>>(d_A, d_B, d_C, N);
    }
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float ms_total = 0.0f;
    cudaEventElapsedTime(&ms_total, start, stop);
    float ms_avg = ms_total / NUM_RUNS;

    /* FLOPs = 2 * N^3 (one multiply + one add per k-step) */
    double flops  = 2.0 * (double)N * N * N;
    double gflops = flops / (ms_avg * 1e-3) / 1e9;

    /* Theoretical DRAM traffic (no reuse): 2*N^3 + N^2 elements * 4 bytes */
    double bytes_theory = (2.0 * N * N * N + (double)N * N) * 4.0;
    double ai_theory    = flops / bytes_theory;

    printf("Avg time (%d runs): %.3f ms\n", NUM_RUNS, ms_avg);
    printf("Achieved:           %.2f GFLOP/s\n", gflops);
    printf("Theoretical AI:     %.4f FLOP/byte\n", ai_theory);
    printf("Roofline bound:     memory-bound (AI < ridge point)\n");

    /* Copy result back (sanity check) */
    cudaMemcpy(h_C, d_C, size, cudaMemcpyDeviceToHost);
    printf("C[0][0] = %.6f  (non-zero sanity check)\n", h_C[0]);

    /* Cleanup */
    cudaFree(d_A); cudaFree(d_B); cudaFree(d_C);
    free(h_A); free(h_B); free(h_C);
    cudaEventDestroy(start); cudaEventDestroy(stop);

    return 0;
}
