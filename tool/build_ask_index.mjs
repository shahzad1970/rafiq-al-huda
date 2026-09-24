// Derived local search index, not a new translation or a trained model.
import fs from 'node:fs';
import crypto from 'node:crypto';

const normalize = s => s.toLowerCase()
  .replace(/[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed\u0640]/g, '')
  .replace(/[أإآٱ]/g, 'ا').replace(/ى/g, 'ي');
const stop = new Set('a an the of to in on and or is are was were be been being it its this that those these for from with as at by who what when where why how do does did can could would should me my you your we our they their them he his she her have has had about tell explain please say says said'.split(' '));
const stem = s => /^[a-z]+$/.test(s) && s.length > 4 && s.endsWith('s') && !s.endsWith('ss') ? s.slice(0,-1) : s;
const terms = s => normalize(s).match(/[a-z0-9\u0621-\u063a\u0641-\u064a]+/g)?.filter(t => !stop.has(t)).map(stem) ?? [];
const documents = [], postings = {};
function add(meta, text) {
  const counts = new Map();
  for (const t of terms(text)) counts.set(t, (counts.get(t) ?? 0) + 1);
  const i = documents.length;
  documents.push({...meta, length: [...counts.values()].reduce((a,b)=>a+b,0)});
  for (const [t, count] of counts) (postings[t] ??= []).push(i,count);
}
const read = path => JSON.parse(fs.readFileSync(path,'utf8'));
const quran = read('assets/data/quran_v1.json');
const translation = read('assets/data/ask_translation.json');
for (const [key, ayah] of Object.entries(quran.ayahs)) {
  const row=translation.ayahs[key];
  if(!row?.translation) throw new Error(`Missing translation ${key}`);
  add({id:`quran:${key}`, surah:Number(key.split(':')[0]), ayah:Number(key.split(':')[1])},
    `${ayah.uthmani} ${row.translation}`);
}
const catalog = read('assets/data/hadith/catalog.json');
for (const collection of catalog.collections) {
  for (const book of collection.books) {
    for (const h of read(`assets/data/hadith/${book.file}`)) {
      // AI translations must never become evidence for another AI answer.
      if (!h.english?.trim()) continue;
      add({id:h.id, file:book.file, collection:collection.title, number:h.number, book:book.title},
        `${h.english} ${h.arabic ?? ''}`);
    }
  }
}
const output = {version:2, hadithRevision:catalog.commit, translationVersion:translation.edition.version,
  chapters:quran.chapters.map(c=>({number:c.number,name:c.simpleName,arabic:c.arabicName})),
  quranSha256:crypto.createHash('sha256').update(fs.readFileSync('assets/data/quran_v1.json')).digest('hex'),
  documents, postings};
fs.writeFileSync('assets/data/ask_index.json', JSON.stringify(output));
console.log(`${documents.length} sources; ${Object.keys(postings).length} terms; ${fs.statSync('assets/data/ask_index.json').size} bytes`);
