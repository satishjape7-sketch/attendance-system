import {Router} from 'express';
import bcrypt from 'bcryptjs';
import {z} from 'zod';
import {pool} from '../../database/pool.js';
import {authenticate,adminOnly} from '../../middleware/auth.js';
import {createUserSchema,historySchema} from '../../lib/validation.js';
import {AppError} from '../../lib/errors.js';
export const userRoutes=Router();
userRoutes.use(authenticate,adminOnly);
userRoutes.get('/',async(req,res)=>{
 const {page,limit}=historySchema.parse(req.query);
 const {rows}=await pool.query('SELECT id,name,email,role,active,created_at FROM users ORDER BY created_at DESC,id LIMIT $1 OFFSET $2',[limit+1,(page-1)*limit]);
 res.json({data:rows.slice(0,limit),page,hasMore:rows.length>limit});
});
userRoutes.post('/',async(req,res)=>{
 const input=createUserSchema.parse(req.body),hash=await bcrypt.hash(input.password,12);
 const client=await pool.connect();
 try{
  await client.query('BEGIN');
  const {rows}=await client.query('INSERT INTO users(name,email,password_hash,role) VALUES($1,$2,$3,$4) RETURNING id,name,email,role,active',[input.name,input.email,hash,input.role]);
  await client.query('INSERT INTO audit_events(actor_id,action,target_id) VALUES($1,$2,$3)',[req.user.id,'user.created',rows[0].id]);
  await client.query('COMMIT');res.status(201).json({data:rows[0]});
 }catch(error){await client.query('ROLLBACK');throw error;}finally{client.release();}
});
userRoutes.patch('/:id/status',async(req,res)=>{
 const id=z.string().uuid().parse(req.params.id);
 const {active}=z.object({active:z.boolean()}).strict().parse(req.body);
 if(id===req.user.id)throw new AppError(400,'SELF_UPDATE','You cannot deactivate your own account');
 const client=await pool.connect();
 try{
  await client.query('BEGIN');
  const {rows}=await client.query("UPDATE users SET active=$1,token_version=token_version+1 WHERE id=$2 AND role='employee' RETURNING id,name,email,role,active",[active,id]);
  if(!rows[0])throw new AppError(404,'NOT_FOUND','Employee not found');
  await client.query('INSERT INTO audit_events(actor_id,action,target_id) VALUES($1,$2,$3)',[req.user.id,active?'user.activated':'user.deactivated',id]);
  await client.query('COMMIT');res.json({data:rows[0]});
 }catch(error){await client.query('ROLLBACK');throw error;}finally{client.release();}
});
