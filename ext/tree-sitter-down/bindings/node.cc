#include <napi.h>

typedef struct TSLanguage TSLanguage;

extern "C" {
extern const TSLanguage *tree_sitter_down(void);
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports["name"] = Napi::String::New(env, "down");
  auto language = Napi::External<TSLanguage>::New(env, (TSLanguage *)tree_sitter_down());
  exports["language"] = language;
  return exports;
}

NODE_API_MODULE(tree_sitter_down, Init)
