import {Router} from 'express';
import {pool} from '../../database/pool.js';
import {env} from '../../config/env.js';
import {authenticate,adminOnly} from '../../middleware/auth.js';
import {historySchema} from '../../lib/validation.js';
import {AppError} from '../../lib/errors.js';
import {attendanceSummaryRoutes,businessDate,dailyRows} from './summary.js';
export const attendanceRoutes=Router();
attendanceRoutes.use(authenticate);
attendanceRoutes.use(attendanceSummaryRoutes);
attendanceRoutes.get('/today',async(req,res)=>{
 const today=await businessDate();
 const [{rows},[day]]=await Promise.all([
  pool.query('SELECT * FROM attendance WHERE user_id=$1 AND (work_date=$2::date OR check_out IS NULL) ORDER BY check_in DESC LIMIT 1',[req.user.id,today]),
  dailyRows(today,today,req.user.id,today)
 ]);
 res.json({data:rows[0]??null,timezone:env.BUSINESS_TIMEZONE,today,status:day?.status??null});
});
attendanceRoutes.post('/check-in',async(req,res)=>{
 const {rows}=await pool.query('INSERT INTO attendance(user_id,work_date) VALUES($1,(now() AT TIME ZONE $2)::date) RETURNING *',[req.user.id,env.BUSINESS_TIMEZONE]);
 res.status(201).json({data:rows[0]});
});
attendanceRoutes.post('/check-out',async(req,res)=>{
 const {rows}=await pool.query('UPDATE attendance SET check_out=clock_timestamp() WHERE user_id=$1 AND check_out IS NULL RETURNING *',[req.user.id]);
 if(!rows[0])throw new AppError(409,'NO_OPEN_SHIFT','No open check-in found');
 res.json({data:rows[0]});
});
attendanceRoutes.get('/history',async(req,res)=>{
 const q=historySchema.parse(req.query);
 const {rows}=await pool.query('SELECT * FROM attendance WHERE user_id=$1 AND ($2::date IS NULL OR work_date >= $2::date) AND ($3::date IS NULL OR work_date <= $3::date) ORDER BY work_date DESC LIMIT $4 OFFSET $5',[req.user.id,q.from??null,q.to??null,q.limit+1,(q.page-1)*q.limit]);
 res.json({data:rows.slice(0,q.limit),page:q.page,hasMore:rows.length>q.limit});
});
attendanceRoutes.get('/report',adminOnly,async(req,res)=>{
 const q=historySchema.parse(req.query);
 const {rows}=await pool.query('SELECT a.*,u.name,u.email FROM attendance a JOIN users u ON u.id=a.user_id WHERE ($1::date IS NULL OR work_date >= $1::date) AND ($2::date IS NULL OR work_date <= $2::date) ORDER BY work_date DESC,u.name,a.id LIMIT $3 OFFSET $4',[q.from??null,q.to??null,q.limit+1,(q.page-1)*q.limit]);
 res.json({data:rows.slice(0,q.limit),page:q.page,hasMore:rows.length>q.limit});
});
