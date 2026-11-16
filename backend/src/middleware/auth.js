import jwt from 'jsonwebtoken';
import {pool} from '../database/pool.js';
import {env} from '../config/env.js';
import {AppError} from '../lib/errors.js';
export async function authenticate(req,res,next){
 const token=req.headers.authorization?.match(/^Bearer (\S+)$/)?.[1];
 if(!token)throw new AppError(401,'UNAUTHORIZED','Sign in to continue');
 let payload;
 try{payload=jwt.verify(token,env.JWT_SECRET,{algorithms:['HS256'],issuer:'attendance-api',audience:'attendance-app'});}
 catch{throw new AppError(401,'UNAUTHORIZED','Session expired. Please sign in again');}
 if(typeof payload==='string'||typeof payload.sub!=='string'||typeof payload.version!=='number')throw new AppError(401,'UNAUTHORIZED','Invalid session');
 const {rows}=await pool.query('SELECT id,role FROM users WHERE id=$1 AND active=true AND token_version=$2',[payload.sub,payload.version]);
 if(!rows[0])throw new AppError(401,'UNAUTHORIZED','Session no longer valid');
 req.user=rows[0];next();
}
export function adminOnly(req,res,next){
 if(req.user?.role!=='admin')throw new AppError(403,'FORBIDDEN','Administrator access required');
 next();
}
