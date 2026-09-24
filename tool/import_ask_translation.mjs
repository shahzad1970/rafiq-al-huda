// QuranEnc allows unchanged republication with attribution/version and updates.
// No source text is rewritten; API rows and publisher metadata are preserved.
import fs from 'node:fs';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
const base='https://quranenc.com/api/v1';
const key='english_rwwad';
const fetchText=url=>execFileSync('curl',['-fsSL','--retry','2','--max-time','30',url],{encoding:'utf8',maxBuffer:16*1024*1024});
const catalog=JSON.parse(fetchText(`${base}/translations/list/en`));
const edition=catalog.translations.find(t=>t.key===key);
if(!edition) throw new Error('Edition no longer in current official catalog');
const quran=JSON.parse(fs.readFileSync('assets/data/quran_v1.json','utf8'));
const ayahs={}, hashes={};
for(const chapter of quran.chapters){
  const url=`${base}/translation/sura/${key}/${chapter.number}`;
  const raw=fetchText(url), rows=JSON.parse(raw).result;
  if(rows.length!==chapter.versesCount) throw new Error(`Incomplete chapter ${chapter.number}`);
  for(const r of rows){
    const id=`${Number(r.sura)}:${Number(r.aya)}`;
    if(!quran.ayahs[id] || ayahs[id] || Number(r.sura)!==chapter.number || typeof r.translation!=='string' || !r.translation.trim()) throw new Error(`Invalid row ${id}`);
    ayahs[id]=r;
  }
  hashes[chapter.number]=crypto.createHash('sha256').update(raw).digest('hex');
}
const latest=JSON.parse(fetchText(`${base}/translations/list/en`)).translations.find(t=>t.key===key);
if(latest?.version!==edition.version || latest?.last_update!==edition.last_update) throw new Error('Edition changed during import; retry');
if(Object.keys(ayahs).length!==6236) throw new Error('Incomplete Quran');
const output={schemaVersion:1,edition,source:'https://quranenc.com/en/browse/english_rwwad',
  terms:'https://quranenc.com/en/home',retrieved:new Date().toISOString(),chapterSha256:hashes,ayahs};
fs.writeFileSync('assets/data/ask_translation.json',JSON.stringify(output));
console.log(`Imported ${Object.keys(ayahs).length} unchanged rows, ${edition.title} v${edition.version}`);
