// Pinned data-only import; no upstream code is executed.
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const commit='df57907be35291c91ad6a6691180e22ca9920784';
const base=`https://raw.githubusercontent.com/fawazahmed0/hadith-api/${commit}`;
const root='assets/data/hadith';
mkdirSync(root,{recursive:true});
const hashes={};
const aiTranslations=JSON.parse(readFileSync('assets/data/hadith_ai_translations.json','utf8')).translations;
const appliedAI=new Set();
async function download(path) {
  const response=await fetch(`${base}/${path}`);
  if(!response.ok) throw new Error(`${path}: ${response.status}`);
  const text=await response.text();
  hashes[path]=createHash('sha256').update(text).digest('hex');
  return text;
}
const editions=JSON.parse(await download('editions.json'));
const collections=[];
// Reader order, not an assertion of relative religious authority.
const order=['bukhari','muslim','abudawud','tirmidhi','nasai','ibnmajah','malik','nawawi','qudsi','dehlawi'];
if(Object.keys(editions).some(id=>!order.includes(id))) throw new Error('Review new collections');
for(const id of order) {
  const source=editions[id];
  for(const language of ['eng','ara']) {
    if(!source.collection.some(e=>e.name===`${language}-${id}`)) throw new Error(`Missing edition ${id}`);
  }
  const [english,arabic]=await Promise.all(['eng','ara'].map(async lang=>JSON.parse(await download(`editions/${lang}-${id}.json`))));
  const identity=h=>[h.hadithnumber,h.arabicnumber,h.reference?.book,h.reference?.hadith].join('|');
  const arabicMap=new Map();
  for(const h of arabic.hadiths) {
    const key=identity(h);
    if(arabicMap.has(key)) throw new Error(`Duplicate Arabic identity: ${id} ${key}`);
    arabicMap.set(key,h);
  }
  const seen=new Set(), books=new Map();
  let unmatchedEnglish=0,unmatchedArabic=0;
  function add(h,en,ar) {
    const key=identity(h);
    const book=String(h.reference?.book ?? 0);
    if(!books.has(book)) books.set(book,[]);
    const record={id:`${id}:${key}`,number:String(h.hadithnumber),
      arabicNumber:String(h.arabicnumber),book,bookNumber:String(h.reference?.hadith ?? ''),
      arabic:ar?.text?.trim()||null,english:en?.text?.trim()||null,
      grades:en?.grades??ar?.grades??[]};
    const ai=aiTranslations[record.id];
    if(ai) {
      if(record.english || !record.arabic) throw new Error(`AI translation cannot replace source or translate absent Arabic: ${record.id}`);
      if(createHash('sha256').update(record.arabic).digest('hex')!==ai.arabicSha256) throw new Error(`AI translation Arabic changed: ${record.id}`);
      if(typeof ai.text!=='string'||!ai.text.trim())throw new Error('Empty AI translation');
      record.aiEnglish=ai.text;
      record.aiTranslationNote=ai.note??null;
      appliedAI.add(record.id);
    }
    books.get(book).push(record);
  }
  for(const en of english.hadiths) {
    const key=identity(en);
    if(seen.has(key)) throw new Error(`Duplicate English identity: ${id} ${key}`);
    seen.add(key);
    const ar=arabicMap.get(key);
    if(!ar) unmatchedEnglish++;
    add(en,en,ar); arabicMap.delete(key);
  }
  for(const ar of arabicMap.values()) {add(ar,null,ar); unmatchedArabic++;}
  const manifestBooks=[];
  for(const [book,rows] of books) {
    rows.sort((a,b)=>Number(a.number)-Number(b.number));
    const file=`${id}-${book}.json`;
    writeFileSync(`${root}/${file}`,JSON.stringify(rows));
    manifestBooks.push({id:book,title:english.metadata.sections[book]||arabic.metadata.sections[book]||'Unsectioned narrations',
      file,count:rows.length,numbers:[...new Set(rows.map(h=>h.number))]});
  }
  manifestBooks.sort((a,b)=>Number(a.id)-Number(b.id));
  const collection={id,title:source.name,englishEdition:`eng-${id}`,arabicEdition:`ara-${id}`,
    unavailableCount:[...books.values()].flat().filter(h=>!h.arabic&&!h.english).length,
    count:manifestBooks.reduce((n,b)=>n+b.count,0),englishCount:english.hadiths.length,
    arabicCount:arabic.hadiths.length,unmatchedEnglish,unmatchedArabic,books:manifestBooks};
  collections.push(collection);
  console.log(`${id}: ${collection.count} entries, ${books.size} books; unmatched EN/AR ${unmatchedEnglish}/${unmatchedArabic}`);
}
if(appliedAI.size!==Object.keys(aiTranslations).length)throw new Error('Unused AI translation IDs');
writeFileSync(`${root}/catalog.json`,JSON.stringify({version:1,commit,collections}));
writeFileSync('assets/licenses/hadith-api.txt',await download('LICENSE'));
writeFileSync('docs/hadith-import-manifest.json',JSON.stringify({commit,hashes,collections:collections.map(({books,...c})=>c)},null,2)+'\n');
