--!strict
export type Result = {
	jobId: string,
	operationId: string,
	dollars: number,
	xp: number,
}
export type Snapshot = {
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
	destination: { number }?,
}
return {}
