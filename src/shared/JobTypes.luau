--!strict
local ClientDialogue = require("./ClientDialogue")
local FirstSteps = require("./FirstSteps")
export type Result = {
	jobId: string,
	operationId: string,
	dollars: number,
	xp: number,
	primaryColorId: string?,
	secondaryColorId: string?,
}
export type Offer = {
	clientKey: string?,
	id: string,
	titleKey: string,
	briefKey: string,
	colorId: string,
	secondaryColorId: string?,
	requiredXP: number,
	unlocked: boolean,
	reward: number,
	xp: number,
}
export type AcceptAck = { requestId: string, jobId: string, offerId: string, error: string }
export type Snapshot = {
	acceptAck: AcceptAck?,
	available: boolean,
	phase: string,
	jobId: string,
	workId: string,
	sequence: number,
	mask: string,
	count: number,
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
