# llama.cpp Adapter Direction

Caliper v1 targets llama.cpp first, but does not vendor llama.cpp.

Host apps can integrate by:

1. Building or adding `llama.xcframework`.
2. Bridging llama.cpp token streaming into a Swift async sequence.
3. Passing token strings through `LlamaCppRuntimeAdapter`.

The adapter records operational behavior, not benchmark scores.

Recommended model metadata:

- model identifier
- family
- parameter count
- quantization
- context length
- runtime name
- Metal offload configuration

Recommended request metadata:

- prompt template
- max tokens
- sampling parameters
- structured output mode
