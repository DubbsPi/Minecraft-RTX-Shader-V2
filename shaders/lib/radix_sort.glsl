#ifndef INCLUDE_RADIX_SORT
#define INCLUDE_RADIX_SORT

#extension GL_KHR_shader_subgroup_basic : enable
#extension GL_KHR_shader_subgroup_ballot : enable

#include "settings.glsl"
#include "vertex_util.glsl"


#if defined(GL_KHR_shader_subgroup_basic) && defined(GL_KHR_shader_subgroup_ballot) && !defined(FORCE_NO_SUBGROUPS)
    #define USE_SUBGROUPS
#endif

#define SORT_THREADS 256u
#define SORT_ROUNDS 16u
#define SORT_MAX_SG 16u
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


layout(std430, binding = SRC_K) restrict readonly buffer SrcKeys {uint srcKeys[];};
layout(std430, binding = SRC_V) restrict readonly buffer SrcVals {uint srcVals[];};
layout(std430, binding = DST_K) restrict writeonly buffer DstKeys {uint dstKeys[];};
layout(std430, binding = DST_V) restrict writeonly buffer DstVals {uint dstVals[];};
layout(std430, binding = 10) restrict buffer RadixHist {uint hist[];};


uint popc4(in uvec4 v) {
    return bitCount(v.x) + bitCount(v.y) + bitCount(v.z) + bitCount(v.w);
}

uint digitOf(in uint key) {
    return (key >> (8u * uint(SORT_PASS))) & 0xFFu;
}

uint sortNumTiles(in uint n) {
    return (n + SORT_TILE - 1u) / SORT_TILE;
}


uvec4 peerMask(in uint d, in bool valid) {
    #ifdef GL_NV_shader_subgroup_partitioned
        return subgroupPartitionNV(d) & subgroupBallot(valid);
    #else
        uvec4 m = subgroupBallot(valid);
        for (uint b = 0u; b < 8u; ++b) {
            bool bit = ((d >> b) & 1u) != 0u;
            uvec4 bal = subgroupBallot(bit);
            m &= bit ? bal : ~bal;
        }
        return m;
    #endif
}

void sgSync() {
    subgroupMemoryBarrierShared();
    subgroupBarrier();
}

uint laneBase(in uint tile) {
    return tile * SORT_TILE + gl_SubgroupID * SORT_ROUNDS * gl_SubgroupSize + gl_SubgroupInvocationID;
}


#ifndef USE_SUBGROUPS
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
#else
    #if SORT_STAGE == 0
        shared uint sgHist[SORT_MAX_SG * 256u];

        void main() {
            uint n = TriCounter.quadCount;
            uint numTiles = sortNumTiles(n);
            uint tile = gl_WorkGroupID.x;
            if (tile >= numTiles) return;

            uint tid = gl_LocalInvocationID.x;
            uint sg = gl_SubgroupID;
            uint numSg = gl_NumSubgroups;

            for (uint k = tid; k < numSg * 256u; k += SORT_THREADS) sgHist[k] = 0u;
            barrier();

            uint i0 = laneBase(tile);
            for (uint r = 0u; r < SORT_ROUNDS; ++r) {
                uint i = i0 + r * gl_SubgroupSize;
                bool valid = i < n;
                uint d = valid ? digitOf(srcKeys[i]) : 0u;

                uvec4 peers = peerMask(d, valid);
                uint rank = popc4(peers & gl_SubgroupLtMask);
                if (valid && rank == 0u) sgHist[sg * 256u + d] += popc4(peers);
                sgSync();
            }
            barrier();

            uint sum = 0u;
            for (uint s = 0u; s < numSg; ++s) sum += sgHist[s * 256u + tid];
            hist[tid * numTiles + tile] = sum;
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
        shared uint sgOff[SORT_MAX_SG * 256u];

        void main() {
            uint n = TriCounter.quadCount;
            uint numTiles = sortNumTiles(n);
            uint tile = gl_WorkGroupID.x;
            if (tile >= numTiles) return;

            uint tid = gl_LocalInvocationID.x;
            uint sg = gl_SubgroupID;
            uint numSg = gl_NumSubgroups;
            uint i0 = laneBase(tile);

            for (uint k = tid; k < numSg * 256u; k += SORT_THREADS) sgOff[k] = 0u;
            barrier();

            for (uint r = 0u; r < SORT_ROUNDS; ++r) {
                uint i = i0 + r * gl_SubgroupSize;
                bool valid = i < n;
                uint d = valid ? digitOf(srcKeys[i]) : 0u;

                uvec4 peers = peerMask(d, valid);
                uint rank = popc4(peers & gl_SubgroupLtMask);
                if (valid && rank == 0u) sgOff[sg * 256u + d] += popc4(peers);
                sgSync();
            }
            barrier();

            // Count and offset
            uint run = hist[tid * numTiles + tile];
            for (uint s = 0u; s < numSg; ++s) {
                uint c = sgOff[s * 256u + tid];
                sgOff[s * 256u + tid] = run;
                run += c;
            }
            barrier();

            // Stable scatter
            for (uint r = 0u; r < SORT_ROUNDS; ++r) {
                uint i = i0 + r * gl_SubgroupSize;
                bool valid = i < n;
                uint key = valid ? srcKeys[i] : 0u;
                uint val = valid ? srcVals[i] : 0u;
                uint d = digitOf(key);

                uvec4 peers = peerMask(d, valid);
                uint rank = popc4(peers & gl_SubgroupLtMask);
                uint cnt = popc4(peers);

                if (valid) {
                    uint dst = sgOff[sg * 256u + d] + rank;
                    dstKeys[dst] = key;
                    dstVals[dst] = val;
                }
                sgSync();
                if (valid && rank == 0u) sgOff[sg * 256u + d] += cnt;
                sgSync();
            }
        }
    #endif
#endif


#endif