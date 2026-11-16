import {Router} from 'express';
import rateLimit from 'express-rate-limit';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import {z} from 'zod';
import {pool} from '../../database/pool.js';
import {env} from '../../config/env.js';
import {AppError} from '../../lib/errors.js';
import {loginSchema,passwordSchema} from '../../lib/validation.js';
import {authenticate} from '../../middleware/auth.js';
export const authRoutes=Router();
const dummyHash=await bcrypt.hash('unused-timing-equalizer-password',12);
authRoutes.post('/login',rateLimit({windowMs:900000,limit:10,standardHeaders:'draft-7',legacyHeaders:false,message:{error:{code:'RATE_LIMIT',message:'Too many attempts. Try again later'}}}),async(req,res)=>{
 const input=loginSchema.parse(req.body);
 const {rows}=await pool.query('SELECT * FROM users WHERE email=$1',[input.email]);
 const user=rows[0];
 const valid=await bcrypt.compare(input.password,user?.password_hash??dummyHash);
 if(!valid||!user?.active)throw new AppError(401,'INVALID_CREDENTIALS','Email or password is incorrect');
 const token=jwt.sign({version:user.token_version},env.JWT_SECRET,{algorithm:'HS256',subject:user.id,issuer:'attendance-api',audience:'attendance-app',expiresIn:'15m'});
 res.json({data:{token,user:{id:user.id,name:user.name,email:user.email,role:user.role}}});
});
authRoutes.get('/me',authenticate,async(req,res)=>{
 const {rows}=await pool.query('SELECT id,name,email,role FROM users WHERE id=$1',[req.user.id]);res.json({data:rows[0]});
});
authRoutes.post('/logout',authenticate,async(req,res)=>{
 await pool.query('UPDATE users SET token_version=token_version+1 WHERE id=$1',[req.user.id]);res.status(204).end();
});
authRoutes.post('/password',authenticate,async(req,res)=>{
 const input=z.object({currentPassword:z.string().min(1).max(200),newPassword:passwordSchema}).strict().parse(req.body);
 const {rows}=await pool.query('SELECT password_hash FROM users WHERE id=$1',[req.user.id]);
 if(!await bcrypt.compare(input.currentPassword,rows[0].password_hash))throw new AppError(400,'INVALID_PASSWORD','Current password is incorrect');
 const hash=await bcrypt.hash(input.newPassword,12);
 const result=await pool.query('UPDATE users SET password_hash=$1,token_version=token_version+1 WHERE id=$2 AND password_hash=$3',[hash,req.user.id,rows[0].password_hash]);
 if(!result.rowCount)throw new AppError(409,'CONFLICT','Password changed concurrently. Sign in again');
 res.status(204).end();
});
