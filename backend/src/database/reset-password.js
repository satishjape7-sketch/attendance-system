import bcrypt from 'bcryptjs';
import {z} from 'zod';
import {pool} from './pool.js';
import {passwordSchema} from '../lib/validation.js';
const email=z.string().trim().email().transform(v=>v.toLowerCase()).parse(process.env.RESET_EMAIL);
const password=passwordSchema.parse(process.env.RESET_PASSWORD);
const client=await pool.connect();
try {
 const hash=await bcrypt.hash(password,12);
 await client.query('BEGIN');
 const {rows}=await client.query('UPDATE users SET password_hash=$1,token_version=token_version+1 WHERE email=$2 RETURNING id',[hash,email]);
 if(!rows[0])throw new Error('Account not found');
 await client.query("INSERT INTO audit_events(action,target_id) VALUES('user.password_reset_by_operator',$1)",[rows[0].id]);
 await client.query('COMMIT');
 console.log('Password reset; all sessions revoked');
}catch(error){await client.query('ROLLBACK');throw error;}
finally{client.release();await pool.end();}
