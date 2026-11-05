--!strict
-- Public geometry snapshot; the server retains its own immutable validation layout.
export type Box = { x: number, z: number, w: number, d: number, angle: number }
export type Region = Box & { id: string, labelKey: string? }
export type Plan = { halfWidth: number, halfDepth: number, fixed: { Region } }
return {}
