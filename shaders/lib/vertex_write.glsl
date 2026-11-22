if (TriCounter.vertexCount >= uint(MAX_QUADS * 4)) return;

// Note: using uint(gl_VertexIndex); mostly works as well, however roughly half of all terrain below the player is ommitted
uint vertexIndex = atomicAdd(TriCounter.vertexCount, 1u);
uint quadID = vertexIndex >> 2u;
uint corner = vertexIndex & 3u;

if (quadID < uint(MAX_QUADS)) {
    ivec2 base = ivec2(int(quadID % TRIS_PER_ROW), int(quadID / TRIS_PER_ROW)) * 2;
    ivec2 offset = ivec2(int(corner & 1u), int(corner >> 1u));

    imageStore(vertexPositions, base + offset, uvec4(packPos(feetPos), 0u, 0u));

    #ifdef ENTITY_WRITE
        imageStore(vertexAttributes, base + offset, uvec4(packAttributes(entityTexcoordOffset + texcoord, glcolor), 0u, 0u));
    #else
        imageStore(vertexAttributes, base + offset, uvec4(packAttributes(texcoord, glcolor), 0u, 0u));
    #endif

    if (corner == 3u) atomicAdd(TriCounter.quadCount, 1u);
}