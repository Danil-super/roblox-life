--!strict
local ClientDialogue = require("./ClientDialogue")
local FirstSteps = require("./FirstSteps")
local Geometry = require("./PaintGeometry")
local PaintFinish = require("./PaintFinish")
export type Result = {
	sizes: { Geometry.Size }?,
	jobId: string,
	operationId: string,
	dollars: number,
	xp: number,
	baseDollars: number?,
	perfectBonus: number?,
	primaryColorId: string?,
	secondaryColorId: string?,
	finish: PaintFinish.Data?,
}
export type Offer = {
	perfectBonus: number?,
	clientKey: string?,
	id: string,
	titleKey: string,
	briefKey: string,
	colorId: string,
	secondaryColorId: string?,
	requiredXP: number,
	needsCleaning: boolean?,
	unlocked: boolean,
	reward: number,
	xp: number,
}
export type AcceptAck = { requestId: string, jobId: string, offerId: string, error: string }
export type Snapshot = {
	acceptAck: AcceptAck?,
	reviewAck: string?,
	checkpointSaved: boolean?,
	canTouchUp: boolean?,
	touchingUp: boolean?,
	available: boolean,
	phase: string,
	jobId: string,
	workId: string,
	sequence: number,
	mask: string,
	count: number,
	preparationRequired: number?,
	preparedCount: number?,
	reward: number,
	result: Result?,
	near: boolean,
	error: string?,
	location: string?,
	wallName: string?,
	wallId: string?,
	surfaceIndex: number?,
	surfaceTotal: number?,
	destination: { number }?,
	offers: { Offer }?,
	paintingXP: number?,
	contractId: string?,
	requiredColorId: string?,
	toolId: string?,
	clientKey: string?,
	canTalk: boolean?,
	conversation: ClientDialogue.Dialogue?,
	firstSteps: FirstSteps.Progress?,
}
return {}
