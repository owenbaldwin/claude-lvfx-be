DEFAULT_COMPLEXITY_TEMPLATES = [
  { key: "prep_simple",     level: "Very Low",  description: "Simple 2D compositing or prep (e.g. marker removal, plate stabilization, minor roto)" },
  { key: "comp_basic",      level: "Low",       description: "Basic VFX work (e.g. green screen keying, screen replacement, minor FX like glows or muzzle flashes)" },
  { key: "cg_prop_basic",   level: "Low",       description: "Basic CG insertion with minimal lighting interaction (e.g. static props, matte paintings)" },
  { key: "fx_medium",       level: "Medium",    description: "Moderate FX or CG with interaction (e.g. fire, dust sims, basic creature rig, motion-tracked props)" },
  { key: "roto_medium",     level: "Medium",    description: "Standard character roto or animation blending, multiple assets in one shot" },
  { key: "fx_high",         level: "High",      description: "Complex FX (e.g. fluid simulation, destruction), or CG environments with lighting and shadows" },
  { key: "creature_high",   level: "High",      description: "Full CG creatures or digital doubles with performance capture and facial animation" },
  { key: "sim_vhigh",       level: "Very High", description: "Highly technical simulation (e.g. photoreal water, crowd scenes, cloth/hair dynamics)" },
  { key: "comp_vhigh",      level: "Very High", description: "Multi-pass photoreal compositing with complex lighting, integration, and re-lighting" },
  { key: "vp_vhigh",        level: "Very High", description: "Virtual production or LED volume integration with real-time lighting and parallax correction" },
  { key: "ai_vhigh",        level: "Very High", description: "AI-assisted facial transfer or de-aging with multiple manual overrides and retargeting passes" },
  { key: "stereo_medium",   level: "Medium",    description: "Stereo conversion and depth grading with tracking and roto support" },
  { key: "delivery_low",    level: "Low",       description: "Delivery-only work (e.g. burn-ins, color space conversion, slate prep)" },
  { key: "pipeline_medium", level: "Medium",    description: "Pipeline and render pass management (e.g. AOVs, cryptomatte, OCIO setup)" }
].freeze
