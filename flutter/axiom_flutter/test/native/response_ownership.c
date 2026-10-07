/* Controlled C ABI fixture: poison native data after callback ownership ends. */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
typedef struct {const uint8_t *ptr; size_t len;} S;
typedef struct {uint8_t *ptr; size_t len;} B;
typedef struct {uint64_t id; int32_t event, status; B data, error;} R;
typedef void (*Callback)(const R*);
static Callback callback;
static uint64_t ids[1024];static B payloads[1024];static size_t used, sent;
void axiom_register_callback(Callback cb) {callback=cb;}
void axiom_free_response_buffer(R *r) {
  if(r->data.ptr) memset(r->data.ptr,0xa5,r->data.len);
  if(r->error.ptr) memset(r->error.ptr,0xa5,r->error.len);
  /* Retain poisoned storage until exit: old readers fail deterministically, without UAF in the fixture. */
  free(r);
}
void axiom_process_responses(void) {
  if(!callback)return;
  while(sent<used) {
    R *r=calloc(1,sizeof(R));r->id=ids[sent];r->event=1;r->data=payloads[sent];callback(r);
    R *end=calloc(1,sizeof(R));end->id=ids[sent++];callback(end);
  }
}
int32_t axiom_initialize(S db) {(void)db;return 0;}
int32_t axiom_load_contract(S ns,S url,B body,S sig,S key) {
  (void)ns;(void)url;(void)sig;(void)key;
  return body.len && body.ptr[0]=='{' ? 0 : 10;
}
int32_t axiom_call(uint64_t id,S ns,uint32_t ep,S method,S path,S trace,S headers,B input) {
  (void)ns;(void)ep;(void)method;(void)path;(void)trace;(void)headers;
  if(used>=1024)return 14;
  ids[used]=id;payloads[used].ptr=malloc(input.len);payloads[used].len=input.len;
  memcpy(payloads[used++].ptr,input.ptr,input.len);return 0;
}
void axiom_set_auth_token(S n,S m,S t){(void)n;(void)m;(void)t;}
void axiom_clear_auth_token(S n,S m){(void)n;(void)m;}
void axiom_send_stream_message(uint64_t id,B b){(void)id;(void)b;}
