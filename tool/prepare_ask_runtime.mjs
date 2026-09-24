import {execFileSync} from 'node:child_process';
import {createReadStream, existsSync, mkdirSync, mkdtempSync, writeFileSync, readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {createHash} from 'node:crypto';

const checksum = 'aaacd87714428116f3e6fa0ea1eba127607223b1c329baba87161c90b17ebce4';
const root = 'ios/LocalQwen/Artifacts';
const marker = path.join(root,'verified-b11065.sha256');
if (existsSync(marker) && readFileSync(marker,'utf8').trim() === checksum && existsSync(path.join(root,'build-apple/llama.xcframework/Info.plist'))) {
  console.log('Pinned llama.cpp runtime already installed.'); process.exit(0);
}
const work = mkdtempSync(path.join(tmpdir(),'quran-ask-runtime-'));
const zip = path.join(work,'llama.zip');
execFileSync('curl',['-fL','--retry','2','--max-time','180',
  'https://github.com/ggml-org/llama.cpp/releases/download/b11065/llama-b11065-xcframework.zip','-o',zip],{stdio:'inherit'});
const sha = createHash('sha256');
for await (const data of createReadStream(zip)) sha.update(data);
if (sha.digest('hex') !== checksum) throw new Error('Runtime checksum mismatch');
mkdirSync(root,{recursive:true});
execFileSync('unzip',['-q','-o',zip,'-d',root]);
writeFileSync(marker,checksum+'\n');
console.log('Verified llama.cpp b11065 installed. Download archive retained at '+zip);
