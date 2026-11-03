--!strict
export type Snapshot = {
	available: boolean,
	phase: string,
	jobId: string,
	workId: string,
	sequence: number,
	mask: string,
	count: number,
	reward: number,
	near: boolean,
	error: string?,
	location: string?,
	destination: { number }?,
}
return {}
