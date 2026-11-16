import {z} from 'zod';
export const passwordSchema=z.string().min(12).max(72).refine(v=>Buffer.byteLength(v,'utf8')<=72,'Password exceeds 72 UTF-8 bytes');
export const loginSchema=z.object({email:z.string().trim().email().max(254).transform(v=>v.toLowerCase()),password:z.string().min(1).max(200)}).strict();
export const createUserSchema=z.object({name:z.string().trim().min(1).max(100),email:z.string().trim().email().max(254).transform(v=>v.toLowerCase()),password:passwordSchema,role:z.enum(['admin','employee']).default('employee')}).strict();
export const dateSchema=z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(v=>{const d=new Date(v);return !Number.isNaN(d.getTime())&&d.toISOString().slice(0,10)===v;},'Invalid calendar date');
export const historySchema=z.object({from:dateSchema.optional(),to:dateSchema.optional(),page:z.coerce.number().int().min(1).max(100000).default(1),limit:z.coerce.number().int().min(1).max(100).default(30)}).refine(v=>!v.from||!v.to||v.from<=v.to,'Invalid date range');
