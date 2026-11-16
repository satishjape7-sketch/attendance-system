import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';

test('PostgreSQL workflow, role enforcement, concurrency and revocation',
 {skip:!process.env.TEST_DATABASE_URL},async()=>{
 const {default:pg}=await import('pg');
 const {default:request}=await import('supertest');
 const {default:bcrypt}=await import('bcryptjs');
 const schema='test_'+randomUUID().replaceAll('-','');
 const control=new pg.Pool({connectionString:process.env.TEST_DATABASE_URL});
 let pool;
 try{
  await control.query('CREATE SCHEMA '+schema);
  const url=new URL(process.env.TEST_DATABASE_URL);
  url.searchParams.set('options','-c search_path='+schema+',public');
  process.env.DATABASE_URL=url.toString();
  process.env.NODE_ENV='test';
  process.env.JWT_SECRET='integration-only-secret-with-32-characters';
  const {app}=await import('../src/app.js');
  ({pool}=await import('../src/database/pool.js'));
  await pool.query(await readFile(new URL('../migrations/001_initial.sql',import.meta.url),'utf8'));
  const hash=await bcrypt.hash('test-password-123',12);
  await pool.query("INSERT INTO users(name,email,password_hash,role) VALUES('Admin','admin@example.com',$1,'admin')",[hash]);
  const adminLogin=await request(app).post('/api/v1/auth/login').send({email:'admin@example.com',password:'test-password-123'}).expect(200);
  const admin='Bearer '+adminLogin.body.data.token;
  const employee=await request(app).post('/api/v1/users').set('Authorization',admin).send({name:'Employee',email:'employee@example.com',password:'test-password-123'}).expect(201);
  const login=await request(app).post('/api/v1/auth/login').send({email:'employee@example.com',password:'test-password-123'}).expect(200);
  const token='Bearer '+login.body.data.token;
  await request(app).get('/api/v1/users').set('Authorization',token).expect(403);
  await request(app).get('/api/v1/attendance/report').set('Authorization',token).expect(403);
  const attempts=await Promise.all([1,2].map(()=>request(app).post('/api/v1/attendance/check-in').set('Authorization',token)));
  assert.deepEqual(attempts.map(r=>r.status).sort(),[201,409]);
  await request(app).post('/api/v1/attendance/check-out').set('Authorization',token).expect(200);
  await request(app).post('/api/v1/attendance/check-out').set('Authorization',token).expect(409);
  const history=await request(app).get('/api/v1/attendance/history').set('Authorization',token).expect(200);
  assert.equal(history.body.data.length,1);assert.ok(history.body.data[0].check_out);
  await request(app).patch('/api/v1/users/'+employee.body.data.id+'/status').set('Authorization',admin).send({active:false}).expect(200);
  await request(app).get('/api/v1/auth/me').set('Authorization',token).expect(401);
  await request(app).post('/api/v1/auth/logout').set('Authorization',admin).expect(204);
  await request(app).get('/api/v1/auth/me').set('Authorization',admin).expect(401);
 }finally{
  if(pool)await pool.end();
  await control.query('DROP SCHEMA IF EXISTS '+schema+' CASCADE');
  await control.end();
 }
});
