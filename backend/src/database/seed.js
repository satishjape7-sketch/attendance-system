import bcrypt from 'bcryptjs';
import {z} from 'zod';
import {pool} from './pool.js';
import {passwordSchema} from '../lib/validation.js';
const input=z.object({ADMIN_EMAIL:z.string().trim().email().transform(v=>v.toLowerCase()),ADMIN_NAME:z.string().trim().min(1).max(100),ADMIN_PASSWORD:passwordSchema}).parse(process.env);
try{
 const hash=await bcrypt.hash(input.ADMIN_PASSWORD,12);
 const result=await pool.query("INSERT INTO users(name,email,password_hash,role) VALUES($1,$2,$3,'admin') ON CONFLICT(email) DO NOTHING RETURNING id",[input.ADMIN_NAME,input.ADMIN_EMAIL,hash]);
 console.log(result.rowCount?'Admin created':'Email exists; no changes made');
}finally{await pool.end();}
