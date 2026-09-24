// Real model evaluation. No network requests, mocked inference or fixed responses.
// node tool/run_ask_smoke.mjs /absolute/Qwen3.5-4B-Q4_K_M.gguf
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const model = process.argv[2];
const qwen25 = process.argv.includes('--qwen25');
if (!model) throw new Error('Supply the downloaded GGUF path');
const sha = createHash('sha256');
for await (const bytes of fs.createReadStream(model)) sha.update(bytes);
const checksum = sha.digest('hex');
if (checksum !== (qwen25 ? '6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e' : '00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4')) throw new Error('Wrong model checksum');
const results=[];
for (const name of ['supported','hadith','unsupported','injection']) {
  const fixture = `test/fixtures/ask/${name}.json`;
  const run = spawnSync('/usr/bin/time',['-l',path.resolve('ios/LocalQwen/.build/debug/QwenProbe'),model,fixture,...(qwen25 ? ['--qwen25'] : [])],
    {encoding:'utf8',timeout:120000,maxBuffer:16*1024*1024});
  if (run.status !== 0) throw new Error(`${name}: ${run.error ?? run.stderr.slice(-1500)}`);
  const raw = run.stdout.split('\nElapsed seconds:')[0].trim();
  let answer;
  try { answer = JSON.parse(raw); } catch { answer = null; }
  const valid = Array.isArray(answer?.claims) && answer.claims.every(c=>
    typeof c.text === 'string' && c.text.length > 0 && Array.isArray(c.sources) && c.sources.length > 0 && c.sources.every(n=>n===1));
  const abstentionExpected=['unsupported','injection'].includes(name);
  const passed = valid && (abstentionExpected ? answer.claims.length===0 : answer.claims.length>0);
  results.push({name,passed,answer,raw,
    seconds:Number(run.stdout.match(/Elapsed seconds: ([\d.]+)/)?.[1]),
    maximumResidentBytes:Number(run.stderr.match(/(\d+)\s+maximum resident set size/)?.[1]),
    fixtureSha256:createHash('sha256').update(fs.readFileSync(fixture)).digest('hex')});
  console.log(`${name}: ${passed ? 'PASS' : 'FAIL'} (${results.at(-1).seconds.toFixed(2)} seconds)`);
}
const report={date:new Date().toISOString(),model:qwen25 ? 'Qwen2.5-1.5B Q4_K_M' : 'Qwen3.5-4B Q4_K_M',checksum,runtime:'llama.cpp b11065',
  machine:{platform:os.platform(),architecture:os.arch(),cpu:os.cpus()[0].model,memoryBytes:os.totalmem()},
  interpretation:'Mac smoke tests only. Validates basic source use, structure and abstention in four cases; not a scholarly or iPhone quality evaluation.',results};
fs.writeFileSync(qwen25 ? 'docs/ask-qwen25-smoke.json' : 'docs/ask-model-smoke.json',JSON.stringify(report,null,2)+'\n');
if (results.some(r=>!r.passed)) process.exitCode=1;
