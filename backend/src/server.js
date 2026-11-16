import {app} from './app.js';
import {env} from './config/env.js';
import {pool} from './database/pool.js';
await pool.query('SELECT 1');
const server=app.listen(env.PORT,'0.0.0.0',()=>console.log('Attendance API listening on',env.PORT));
let closing=false;
function shutdown(){
 if(closing)return;closing=true;
 const timeout=setTimeout(()=>process.exit(1),10000).unref();
 server.close(async()=>{await pool.end();clearTimeout(timeout);process.exit(0);});
}
process.on('SIGTERM',shutdown);process.on('SIGINT',shutdown);
