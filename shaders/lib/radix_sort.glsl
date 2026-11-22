#ifndef INCLUDE_RADIX_SORT
#define INCLUDE_RADIX_SORT


#include "settings.glsl"
#include "vertex_util.glsl"

#define SORT_THREADS 256u
#define SORT_ROUNDS  16u
#define SORT_TILE (SORT_THREADS * SORT_ROUNDS)


#if (SORT_PASS & 1) == 0
    #define SRC_K 1
    #define SRC_V 2
    #define DST_K 8
    #define DST_V 9
#else
    #define SRC_K 8
    #define SRC_V 9
    #define DST_K 1
    #define DST_V 2
#endif


layout(std430, binding = SRC_K) restrict readonly buffer SrcKeys { uint srcKeys[]; };
layout(std430, binding = SRC_V) restrict readonly buffer SrcVals { uint srcVals[]; };
layout(std430, binding = DST_K) restrict writeonly buffer DstKeys { uint dstKeys[]; };
layout(std430, binding = DST_V) restrict writeonly buffer DstVals { uint dstVals[]; };
layout(std430, binding = 10) restrict buffer RadixHist { uint hist[]; };


uint digitOf(in uint key) {
    return (key >> (8u * uint(SORT_PASS))) & 0xFFu;
}

uint sortNumTiles(in uint n) {
    return (n + SORT_TILE - 1u) / SORT_TILE;
}


#if SORT_STAGE == 0
    shared uint localHist[256];

    void main() {
        uint n = TriCounter.quadCount;
        uint numTiles = sortNumTiles(n);
        uint tile = gl_WorkGroupID.x;
        if (tile >= numTiles) return;

        uint tid = gl_LocalInvocationID.x;
        localHist[tid] = 0u;
        barrier();

        uint base = tile * SORT_TILE;
        for (uint r = 0u; r < SORT_ROUNDS; ++r) {
            uint i = base + r * SORT_THREADS + tid;
            if (i < n) atomicAdd(localHist[digitOf(srcKeys[i])], 1u);
        }
        barrier();

        hist[tid * numTiles + tile] = localHist[tid];
    }
#elif SORT_STAGE == 1
    shared uint partial[1024];

    void main() {        
        uint tid = gl_LocalInvocationID.x;
        uint numTiles = sortNumTiles(TriCounter.quadCount);
        uint total = 256u * numTiles;
        uint chunk = (total + 1023u) / 1024u;
        uint b = min(tid * chunk, total);
        uint e = min(b + chunk, total);

        uint sum = 0u;
        for (uint i = b; i < e; ++i) sum += hist[i];
        partial[tid] = sum;
        barrier();

        for (uint off = 1u; off < 1024u; off <<= 1u) {
            uint v = (tid >= off)? partial[tid - off] : 0u;
            barrier();
            partial[tid] += v;
            barrier();
        }

        uint run = partial[tid] - sum;
        for (uint i = b; i < e; ++i) {
            uint c = hist[i];
            hist[i] = run;
            run += c;
        }
    }
#elif SORT_STAGE == 2
    shared uint binOffset[256];
    shared uint runCount[256];
    shared uint digs[256];

    void main() {        
        uint n = TriCounter.quadCount;
        uint numTiles = sortNumTiles(n);
        uint tile = gl_WorkGroupID.x;
        if (tile >= numTiles) return;

        uint tid = gl_LocalInvocationID.x;
        binOffset[tid] = hist[tid * numTiles + tile];
        runCount[tid] = 0u;
        barrier();

        uint base = tile * SORT_TILE;
        for (uint r = 0u; r < SORT_ROUNDS; ++r) {
            uint i = base + r * SORT_THREADS + tid;
            bool valid = i < n;
            uint key = valid? srcKeys[i] : 0u;
            uint val = valid? srcVals[i] : 0u;
            uint d = valid? digitOf(key) : 0xFFFFFFFFu;

            digs[tid] = d;
            barrier();

            if (valid) {
                uint rank = 0u;
                for (uint j = 0u; j < tid; ++j) rank += (digs[j] == d)? 1u : 0u;
                uint dst = binOffset[d] + runCount[d] + rank;
                dstKeys[dst] = key;
                dstVals[dst] = val;
            }
            barrier();

            if (valid) atomicAdd(runCount[d], 1u);
        }
    }
#endif


#endif