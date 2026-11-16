import pg from 'pg';
import { env } from '../config/env.js';
// Preserve SQL DATE values as calendar dates instead of timezone-shifted instants.
pg.types.setTypeParser(1082, value => value);
export const pool = new pg.Pool({connectionString:env.DATABASE_URL,max:10,connectionTimeoutMillis:5000,idleTimeoutMillis:30000,statement_timeout:10000});
pool.on('error', error=>console.error('Database pool error:',error.message));
