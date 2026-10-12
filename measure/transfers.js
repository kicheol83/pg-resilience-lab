import http from 'k6/http';
import { sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';
import exec from 'k6/execution';

const BASE_URL = __ENV.BASE_URL || 'http://api:3000/v1';
const RUN_ID = __ENV.RUN_ID || `run-${Date.now()}`;
const RATE = Number(__ENV.RATE || 20);
const DURATION = __ENV.DURATION || '120s';
const ACCOUNTS = Number(__ENV.ACCOUNTS || 40);
const MAX_ATTEMPTS = Number(__ENV.MAX_ATTEMPTS || 40);
const RETRY_SLEEP = Number(__ENV.RETRY_SLEEP || 0.25);
const CURRENCY = 'UZS';

const attempt = new Trend('lab_attempt', true);
const ack = new Counter('lab_ack');
const giveup = new Counter('lab_giveup');

export const options = {
  scenarios: {
    transfers: {
      executor: 'constant-arrival-rate',
      rate: RATE,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: Math.max(10, RATE * 2),
      maxVUs: Math.max(50, RATE * 40),
      gracefulStop: '60s',
    },
  },
  summaryTrendStats: ['avg', 'p(50)', 'p(95)', 'p(99)', 'max'],
  setupTimeout: '120s',
  noConnectionReuse: false,
  dns: { ttl: '1s', select: 'first', policy: 'preferIPv4' },
};

const JSON_HEADERS = { 'Content-Type': 'application/json' };

function postWithRetry(path, body, extraHeaders) {
  for (let i = 0; i < 30; i += 1) {
    const res = http.post(`${BASE_URL}${path}`, JSON.stringify(body), {
      headers: Object.assign({}, JSON_HEADERS, extraHeaders || {}),
      timeout: '10s',
      tags: { phase: 'setup' },
    });
    if (res.status === 201 || res.status === 200) {
      return res.json();
    }
    sleep(1);
  }
  throw new Error(`setup call ${path} failed`);
}

export function setup() {
  const user = postWithRetry('/users', { email: `${RUN_ID}@lab.test`.toLowerCase() });
  const accounts = [];
  for (let i = 0; i < ACCOUNTS; i += 1) {
    const account = postWithRetry('/accounts', { userId: user.id, currency: CURRENCY });
    postWithRetry(
      '/deposits',
      { accountId: account.id, amount: '1000000000', currency: CURRENCY, metadata: { labRun: RUN_ID } },
      { 'Idempotency-Key': `${RUN_ID}-dep-${i}` },
    );
    accounts.push(account.id);
  }
  return { accounts };
}

export default function (data) {
  const n = data.accounts.length;
  const from = data.accounts[Math.floor(Math.random() * n)];
  let to = data.accounts[Math.floor(Math.random() * n)];
  if (to === from) {
    to = data.accounts[(data.accounts.indexOf(from) + 1) % n];
  }
  const key = `${RUN_ID}-${exec.vu.idInTest}-${exec.vu.iterationInScenario}`;
  const body = JSON.stringify({
    fromAccountId: from,
    toAccountId: to,
    amount: String(1 + Math.floor(Math.random() * 1000)),
    currency: CURRENCY,
    metadata: { labRun: RUN_ID, labKey: key },
  });

  for (let i = 1; i <= MAX_ATTEMPTS; i += 1) {
    const res = http.post(`${BASE_URL}/transfers`, body, {
      headers: Object.assign({}, JSON_HEADERS, { 'Idempotency-Key': key }),
      timeout: '10s',
      tags: { phase: 'load' },
    });
    const ok = res.status === 201 || res.status === 200;
    attempt.add(res.timings.duration, { ok: ok ? '1' : '0', status: String(res.status), attempt: String(i), key });
    if (ok) {
      let tx = '';
      try {
        tx = res.json('id') || '';
      } catch (e) {
        tx = '';
      }
      const replay = res.headers['Idempotent-Replay'] === 'true' ? '1' : '0';
      ack.add(1, { tx, key, replay, attempts: String(i) });
      return;
    }
    if (res.status >= 400 && res.status < 500 && res.status !== 409 && res.status !== 408 && res.status !== 429) {
      giveup.add(1, { key, status: String(res.status) });
      return;
    }
    sleep(RETRY_SLEEP);
  }
  giveup.add(1, { key, status: 'exhausted' });
}
