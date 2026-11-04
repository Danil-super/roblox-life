--!strict
local HomePlan = require("./HomePlan")
export type Pose = { x: number, z: number, rotationY: number }
export type Product = {
	id: string,
	dollars: number,
	modelVersion: number,
	width: number,
	depth: number,
	height: number,
}
export type Owned = HomePlan.Item
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
	-- Correlates a purchase response, including refusal; ownership proves success.
	ack: string?,
	-- Placement response identity; a confirmed owned pose still proves success.
	placementAck: string?,
	openShop: boolean?,
	plan: HomePlan.Progress?,
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
