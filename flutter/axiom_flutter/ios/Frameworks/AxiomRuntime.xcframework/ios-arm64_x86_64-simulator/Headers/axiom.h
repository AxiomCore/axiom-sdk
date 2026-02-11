#ifndef AXIOM_RUNTIME_H
#define AXIOM_RUNTIME_H
#include <stdint.h>
#include <stdbool.h>

typedef struct { const uint8_t* ptr; uint64_t len; } AxiomString;
typedef struct { uint8_t* ptr; uint64_t len; } AxiomBuffer;

typedef enum {
    Success = 0,
    UnknownError = 1,
    RequestParsingFailed = 2,
    NetworkError = 3,
    ResponseDeserializationFailed = 4,
    UnknownEndpoint = 5,
    InvalidContract = 10,
    RuntimeTooOld = 11,
    ContractNotLoaded = 12
} FfiError;

typedef struct {
    uint64_t request_id;
    int32_t error_code;
    AxiomBuffer data;
} AxiomResponseBuffer;

typedef void (*AxiomCallback)(AxiomResponseBuffer response);
typedef void (*AxiomAuthCallback)(uint64_t request_id);

void axiom_initialize(AxiomString base_url);
int32_t axiom_load_contract(AxiomBuffer contract_buf);
void axiom_register_callback(AxiomCallback callback);
void axiom_register_auth_provider(AxiomAuthCallback callback);
void axiom_provide_auth_token(uint64_t request_id, AxiomString token);
void axiom_free_buffer(AxiomBuffer buf);
void axiom_process_responses();
void axiom_call(uint64_t request_id, uint32_t endpoint_id, AxiomString path, AxiomBuffer input_buf);

#endif
