// Included by our shaders that use screen-space derivatives. NVIDIA's RTX fork of Godot compiles
// every material a second time with RT defined, as ray-tracing hit shaders, which have no
// derivatives: fwidth/dFdx/dFdy don't compile there and the material would fall back to a default
// one. Under RT the anti-aliasing widths become a small constant and the bump mapping is off (DLSS
// Ray Reconstruction resolves edges). Stock Godot never defines RT, so this is empty there.
// (The same fix as SpeedFest's game/shaders/rt.gdshaderinc on the m7-rtx branch.)
#if defined(RT)
#define fwidth(x) ((x) * 0.0 + 0.001)
#define dFdx(x) ((x) * 0.0)
#define dFdy(x) ((x) * 0.0)
#endif
