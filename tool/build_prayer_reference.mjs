import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
const output=execFileSync('php',['-d','error_reporting=0','tool/prayer_reference.php'],{encoding:'utf8',maxBuffer:8*1024*1024});
const data=JSON.parse(output);
if(data.cases.length!==1056) throw new Error(`Unexpected case count ${data.cases.length}`);
fs.mkdirSync('test/fixtures/prayer',{recursive:true});
fs.writeFileSync('test/fixtures/prayer/mawaqit-reference.json',JSON.stringify(data)+'\n');
console.log(`Generated ${data.cases.length} real PHP reference cases.`);
