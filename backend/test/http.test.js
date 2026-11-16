import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
process.env.NODE_ENV='test';
process.env.DATABASE_URL='postgresql://unused:unused@localhost:5432/unused';
process.env.JWT_SECRET='test-only-secret-of-at-least-32-characters';
const {app}=await import('../src/app.js');
const {pool}=await import('../src/database/pool.js');
after(()=>pool.end());
test('liveness does not require database',async()=>{
 const response=await request(app).get('/health/live').expect(200);
 assert.equal(response.body.status,'ok');
 assert.equal(response.headers['x-powered-by'],undefined);
 assert.ok(response.headers['x-content-type-options']);
});
test('attendance and user routes reject anonymous callers',async()=>{
 for(const path of ['/attendance/today','/attendance/history','/attendance/report','/users']){
  const response=await request(app).get('/api/v1'+path).expect(401);
  assert.equal(response.body.error.code,'UNAUTHORIZED');
 }
});
test('invalid bearer token rejected before database query',async()=>{
 await request(app).get('/api/v1/auth/me').set('Authorization','Bearer invalid').expect(401);
});
test('login rejects invalid input and malformed JSON',async()=>{
 await request(app).post('/api/v1/auth/login').send({email:'bad',password:'x'}).expect(400);
 const response=await request(app).post('/api/v1/auth/login').set('Content-Type','application/json').send('{').expect(400);
 assert.equal(response.body.error.code,'INVALID_BODY');
});
test('unknown routes return stable error envelope',async()=>{
 const response=await request(app).get('/does-not-exist').expect(404);
 assert.equal(response.body.error.code,'NOT_FOUND');
});
