--!strict
export type Pose = { x: number, z: number, rotationY: number }
export type Product = {
	id: string,
	dollars: number,
	modelVersion: number,
	width: number,
	depth: number,
	height: number,
}
export type Owned = { id: string, catalogId: string, purchaseOperationId: string, placed: Pose? }
export type Snapshot = {
	available: boolean,
	dollars: number,
	revision: number,
	editorId: string,
	homeName: string,
	origin: { number },
	nearHome: boolean,
	nearShop: boolean,
	items: { Owned },
	catalog: { Product },
	onboarding: string,
	error: string?,
	ack: string?,
	openShop: boolean?,
}
export type Preview = {
	editorId: string,
	itemId: string,
	sequence: number,
	revision: number,
	pose: Pose?,
	error: string?,
}
return {}
