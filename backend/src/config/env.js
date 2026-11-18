import 'dotenv/config';
import { z } from 'zod';
export const env = z.object({
 NODE_ENV:z.enum(['development','production','test']).default('development'),
 PORT:z.coerce.number().int().min(1).max(65535).default(3000),
 DATABASE_URL:z.string().url(), JWT_SECRET:z.string().min(32),
 CORS_ORIGINS:z.string().default('http://localhost:8080'),
 BUSINESS_TIMEZONE:z.string().default('Asia/Kolkata').refine(v=>{try{new Intl.DateTimeFormat('en',{timeZone:v});return true;}catch{return false;}},'Invalid timezone'),
 TRUST_PROXY:z.enum(['true','false']).default('false'),
 ATTENDANCE_FULL_MINUTES:z.coerce.number().int().min(1).max(1440).default(480),
 ATTENDANCE_HALF_MINUTES:z.coerce.number().int().min(1).max(1440).default(240),
 ATTENDANCE_WEEKLY_OFF:z.coerce.number().int().min(0).max(7).default(7)
}).refine(config => config.ATTENDANCE_HALF_MINUTES <= config.ATTENDANCE_FULL_MINUTES,
 'Half-day minutes must be less than or equal to full-day minutes').parse(process.env);
if(env.NODE_ENV==='production' && env.JWT_SECRET.includes('replace-with')) throw new Error('Configure a random JWT_SECRET');
