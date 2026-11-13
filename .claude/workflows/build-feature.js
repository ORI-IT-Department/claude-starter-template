export const meta = {
  name: 'build-feature',
  description: 'Plan a task, implement it in units, then verify with independent test and review agents',
  whenToUse: 'A feature or fix that touches several files and should be tested and reviewed before commit. Pass the task description as args.',
  phases: [
    { title: 'Plan', detail: 'split the task into small units of work' },
    { title: 'Implement', detail: 'one implementer agent per unit, in order' },
    { title: 'Verify', detail: 'test-runner and reviewer check the result independently' },
    { title: 'Fix', detail: 'repair blocking findings, then verify again' },
  ],
}

// Tunables. Coverage limits are logged when they are hit, never applied silently.
const MAX_UNITS = 4
const MAX_FIX_ROUNDS = 2

const task = typeof args === 'string' ? args : args && args.task
if (!task) {
  throw new Error('build-feature needs a task description, passed as args (a string or {task: "..."})')
}

const PLAN_SCHEMA = {
  type: 'object',
  properties: {
    units: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          goal: { type: 'string' },
          files: { type: 'array', items: { type: 'string' } },
          done_when: { type: 'string' },
        },
        required: ['title', 'goal', 'files', 'done_when'],
      },
    },
    open_questions: { type: 'array', items: { type: 'string' } },
  },
  required: ['units', 'open_questions'],
}

const TEST_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['PASS', 'FAIL'] },
    not_configured: { type: 'array', items: { type: 'string' } },
    failures: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          step: { type: 'string' },
          name: { type: 'string' },
          error: { type: 'string' },
          location: { type: 'string' },
        },
        required: ['step', 'name', 'error'],
      },
    },
  },
  required: ['verdict', 'not_configured', 'failures'],
}

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['APPROVE', 'CHANGES_REQUIRED'] },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          location: { type: 'string' },
          problem: { type: 'string' },
          trigger: { type: 'string' },
          blocking: { type: 'boolean' },
        },
        required: ['location', 'problem', 'blocking'],
      },
    },
  },
  required: ['verdict', 'findings'],
}

// ---- Plan ----
phase('Plan')
const plan = await agent(
  `Read the repository and split this task into small units of work that can be implemented one after another.\n\n` +
    `Task: ${task}\n\n` +
    `Each unit needs a title, a goal, the files it will touch, and a concrete "done when" condition. ` +
    `Prefer fewer, larger units over many tiny ones, and use at most ${MAX_UNITS}. ` +
    `Do not edit any files. List anything genuinely ambiguous in open_questions rather than guessing.`,
  { label: 'plan', schema: PLAN_SCHEMA, agentType: 'Plan' },
)
if (!plan || !plan.units.length) {
  return { status: 'no_plan', task, detail: 'The planning agent returned no units of work.' }
}

let units = plan.units
if (units.length > MAX_UNITS) {
  log(`Plan had ${units.length} units; running the first ${MAX_UNITS} and reporting the rest as skipped.`)
  units = units.slice(0, MAX_UNITS)
}
const skippedUnits = plan.units.slice(units.length).map(u => u.title)

// ---- Implement ----
// Units run in order, not in parallel, because they share one working tree.
phase('Implement')
const implementation = []
for (const [i, unit] of units.entries()) {
  const report = await agent(
    `Implement this unit of work (${i + 1} of ${units.length}).\n\n` +
      `Overall task: ${task}\n` +
      `Unit: ${unit.title}\n` +
      `Goal: ${unit.goal}\n` +
      `Files: ${unit.files.join(', ')}\n` +
      `Done when: ${unit.done_when}`,
    { label: `implement:${unit.title}`, agentType: 'implementer' },
  )
  implementation.push({ unit: unit.title, report: report || 'Agent returned no report.' })
}

// ---- Verify (and fix) ----
// The test-runner and the reviewer are separate agents that never see the
// implementer's own account of its work, so the check is independent.
async function verify(round) {
  const [tests, review] = await parallel([
    () => agent('Run the project checks and report the results.', {
      label: `tests:round-${round}`, phase: 'Verify', schema: TEST_SCHEMA, agentType: 'test-runner',
    }),
    () => agent(`Review the uncommitted changes in this repository. The stated task was: ${task}`, {
      label: `review:round-${round}`, phase: 'Verify', schema: REVIEW_SCHEMA, agentType: 'reviewer',
    }),
  ])
  return { tests, review }
}

function blockers(result) {
  const out = []
  if (!result.tests) out.push('The test-runner agent returned no result, so the checks are unverified.')
  else if (result.tests.verdict === 'FAIL') {
    for (const f of result.tests.failures) {
      out.push(`Check failure in ${f.step}: ${f.name}: ${f.error}${f.location ? ` (${f.location})` : ''}`)
    }
    if (!result.tests.failures.length) out.push('The checks failed but no failure details were reported.')
  }
  if (!result.review) out.push('The reviewer agent returned no result, so the change is unreviewed.')
  else {
    for (const f of result.review.findings.filter(f => f.blocking)) {
      out.push(`Review finding at ${f.location}: ${f.problem}${f.trigger ? ` Trigger: ${f.trigger}` : ''}`)
    }
  }
  return out
}

let round = 1
let result = await verify(round)
let open = blockers(result)

while (open.length && round <= MAX_FIX_ROUNDS) {
  log(`Round ${round}: ${open.length} blocking item(s); sending them to an implementer.`)
  await agent(
    `Fix these blocking problems in the uncommitted changes. Fix the code, not the tests, ` +
      `unless a test itself is the thing that is wrong.\n\n` +
      `Overall task: ${task}\n\nProblems:\n- ${open.join('\n- ')}`,
    { label: `fix:round-${round}`, phase: 'Fix', agentType: 'implementer' },
  )
  round += 1
  result = await verify(round)
  open = blockers(result)
}

if (open.length) {
  log(`Stopped after ${MAX_FIX_ROUNDS} fix round(s) with ${open.length} blocking item(s) still open.`)
}

return {
  status: open.length ? 'needs_attention' : 'ready_to_commit',
  task,
  units_implemented: implementation,
  units_skipped: skippedUnits,
  open_questions: plan.open_questions,
  verify_rounds: round,
  checks_not_configured: result.tests ? result.tests.not_configured : [],
  blocking_items: open,
  non_blocking_findings: result.review ? result.review.findings.filter(f => !f.blocking) : [],
}
