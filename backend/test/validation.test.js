import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createUserSchema,dateSchema,historySchema,passwordSchema} from '../src/lib/validation.js';

test('employee creation normalizes email and defaults role',()=>{
 const user=createUserSchema.parse({name:' Alice ',email:'Alice@Example.com',password:'a-long-password-123'});
 assert.equal(user.email,'alice@example.com');assert.equal(user.name,'Alice');assert.equal(user.role,'employee');
});
test('rejects privileged unknown properties and short passwords',()=>{
 assert.equal(createUserSchema.safeParse({name:'Alice',email:'alice@example.com',password:'short',active:true}).success,false);
 assert.equal(passwordSchema.safeParse('🔒'.repeat(24)).success,false);
});
test('rejects impossible dates and reversed or unbounded pagination',()=>{
 assert.equal(dateSchema.safeParse('2026-02-30').success,false);
 assert.equal(dateSchema.safeParse('2024-02-29').success,true);
 assert.equal(historySchema.safeParse({from:'2026-03-01',to:'2026-02-01'}).success,false);
 assert.equal(historySchema.safeParse({limit:100000}).success,false);
 assert.equal(historySchema.parse({page:'2'}).page,2);
});
