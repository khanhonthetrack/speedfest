// Included by shaders that use fwidth(). NVIDIA's RTX fork of Godot (docs/RTX.md) compiles every
// material a second time with RT defined, as ray-tracing hit shaders, and those have no screen-space
// derivatives: fwidth() doesn't compile there and the material falls back to a default one. Under RT
// the anti-aliasing widths become a small constant instead; DLSS Ray Reconstruction resolves edges
// from its jittered samples. Mainline Godot never defines RT, so this is empty there.
#if defined(RT)
#define fwidth(x) ((x) * 0.0 + 0.001)
#endif
