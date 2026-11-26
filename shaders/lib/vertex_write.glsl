valid = valid && (TriCounter.rebuildFlag != 0u);

bool doWrite = false;
uint quadSlot = 0u;
uint corner = uint(gl_VertexID) & 3u;

#ifdef USE_SUBGROUPS
    uint vid = uint(gl_VertexID);
    uint lane = gl_SubgroupInvocationID;

    bool leader = valid && corner == 0u;
    uvec4 ballot = subgroupBallot(leader);
    uint numQuads = subgroupBallotBitCount(ballot);
    uint rank = subgroupBallotExclusiveBitCount(ballot);

    uint baseQuad = 0u;
    if (subgroupElect() && numQuads > 0u) {
        baseQuad = atomicAdd(TriCounter.quadCount, numQuads);
        atomicAdd(TriCounter.vertexCount, numQuads * 4u);
    }
    baseQuad = subgroupBroadcastFirst(baseQuad);

    uint myQuad = baseQuad + rank;
    uint srcLane = lane - corner;
    uint slot = subgroupShuffle(myQuad, srcLane);
    uint srcVid = subgroupShuffle(vid, srcLane);
    uint srcLead = subgroupShuffle(leader? 1u : 0u, srcLane);

    bool sameQuad = (corner <= lane) && (srcVid == vid - corner) && (srcLead == 1u);

    doWrite = valid && sameQuad;
    quadSlot = slot;
#else
    if (valid) {
        uint vertexIndex = atomicAdd(TriCounter.vertexCount, 1u);
        quadSlot = vertexIndex >> 2u;
        corner = vertexIndex & 3u;
        doWrite = true;
    }
#endif

if (doWrite && quadSlot < uint(MAX_QUADS)) {
    ivec2 base = ivec2(int(quadSlot % TRIS_PER_ROW), int(quadSlot / TRIS_PER_ROW)) * 2;
    ivec2 offset = ivec2(int(corner & 1u), int(corner >> 1u));

    imageStore(vertexPositions, base + offset, uvec4(packPos(feetPos), 0u, 0u));

    #ifdef ENTITY_WRITE
        imageStore(vertexAttributes, base + offset, uvec4(packAttributes(entityTexcoordOffset + texcoord, glcolor), 0u, 0u));
        Slots.entitySlots[quadSlot] = assignedSlot;    
    #else
        imageStore(vertexAttributes, base + offset, uvec4(packAttributes(texcoord, glcolor), 0u, 0u));
    #endif

    #ifndef USE_SUBGROUPS
        if (corner == 3u) atomicAdd(TriCounter.quadCount, 1u);
    #endif
}