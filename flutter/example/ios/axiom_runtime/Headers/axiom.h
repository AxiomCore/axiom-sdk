
#ifndef AXIOM_RUNTIME_H
#define AXIom_RUNTIME_H
#include <stdint.h>
typedef struct { const uint8_t* ptr; uint64_t len; } AxiomString;
typedef struct { uint8_t* ptr; uint64_t len; } AxiomBuffer;
int32_t axiom_call(uint32_t endpointId, AxiomBuffer input, AxiomBuffer* output);
void axiom_initialize(AxiomString);
void axiom_free_buffer(AxiomBuffer);
#endif
