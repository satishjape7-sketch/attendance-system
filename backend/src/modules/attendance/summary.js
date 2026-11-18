import {Router} from 'express';
import {z} from 'zod';
import {pool} from '../../database/pool.js';
import {env} from '../../config/env.js';
import {adminOnly} from '../../middleware/auth.js';
import {dateSchema} from '../../lib/validation.js';
import {AppError} from '../../lib/errors.js';

export const attendanceSummaryRoutes = Router();
const userId = z.string().uuid();
const workDate = dateSchema.refine(value => value >= '0001-01-01');
const month = z.string().regex(/^\d{4}-\d{2}$/)
  .refine(value => dateSchema.safeParse(`${value}-01`).success && value >= '0001-01');

export async function businessDate() {
  const {rows: [row]} = await pool.query(
    'SELECT (now() AT TIME ZONE $1)::date::text AS today', [env.BUSINESS_TIMEZONE]);
  return row.today;
}

export async function dailyRows(start, end, selectedUser, today) {
  const {rows} = await pool.query(`
    WITH dates AS (
      SELECT $1::date + offset_days AS day
      FROM generate_series(0, $2::date - $1::date) AS series(offset_days)
    )
    SELECT u.id AS user_id, u.name, u.email, u.role, d.day::text AS work_date,
      a.check_in, a.check_out, c.reason AS correction_reason,
      CASE
        WHEN c.status IS NOT NULL THEN c.status
        WHEN a.check_out IS NOT NULL THEN
          CASE WHEN a.check_out - a.check_in >= make_interval(mins => $6::int) THEN 'present'
               WHEN a.check_out - a.check_in >= make_interval(mins => $7::int) THEN 'half_day'
               ELSE 'absent' END
        WHEN a.check_in IS NOT NULL THEN
          CASE WHEN d.day = $5::date THEN 'checked_in' ELSE 'missing_checkout' END
        WHEN NOT eligibility.active THEN 'inactive'
        WHEN EXTRACT(ISODOW FROM d.day) = $8::int THEN 'day_off'
        WHEN d.day = $5::date THEN 'pending'
        ELSE 'absent'
      END AS status
    FROM dates d
    JOIN users u ON (u.created_at AT TIME ZONE $4)::date <= d.day
      AND ($3::uuid IS NULL OR u.id = $3)
    LEFT JOIN attendance a ON a.user_id = u.id AND a.work_date = d.day
    LEFT JOIN attendance_corrections c ON c.user_id = u.id AND c.work_date = d.day
    LEFT JOIN LATERAL (
      SELECT action, created_at FROM audit_events
      WHERE target_id = u.id AND action IN ('user.activated', 'user.deactivated')
      ORDER BY (created_at < ((d.day + 1)::timestamp AT TIME ZONE $4)) DESC,
        created_at DESC, id DESC LIMIT 1
    ) status_event ON true
    CROSS JOIN LATERAL (
      SELECT CASE
        WHEN status_event.created_at < ((d.day + 1)::timestamp AT TIME ZONE $4)
          THEN status_event.action = 'user.activated'
        WHEN status_event.created_at IS NOT NULL THEN true
        ELSE u.active
      END AS active
    ) eligibility
    WHERE $3::uuid IS NULL OR eligibility.active OR a.id IS NOT NULL OR c.user_id IS NOT NULL
    ORDER BY d.day, lower(u.name), u.id
  `, [start, end, selectedUser, env.BUSINESS_TIMEZONE, today,
    env.ATTENDANCE_FULL_MINUTES, env.ATTENDANCE_HALF_MINUTES, env.ATTENDANCE_WEEKLY_OFF]);
  return rows;
}

attendanceSummaryRoutes.get('/team-day', adminOnly, async (req, res) => {
  const {date} = z.object({date: workDate.optional()}).parse(req.query);
  const today = await businessDate();
  const day = date ?? today;
  if (day > today) throw new AppError(400, 'FUTURE_DATE', 'Choose today or a previous date');
  res.json({date: day, today, data: await dailyRows(day, day, null, today)});
});

attendanceSummaryRoutes.get('/calendar', async (req, res) => {
  const query = z.object({month: month.optional(), userId: userId.optional()}).parse(req.query);
  if (query.userId && req.user.role !== 'admin') {
    throw new AppError(403, 'FORBIDDEN', 'Only administrators can view another user’s attendance');
  }
  const today = await businessDate();
  const selectedMonth = query.month ?? today.slice(0, 7);
  const start = `${selectedMonth}-01`;
  const lastDay = new Date(`${start}T00:00:00Z`);
  lastDay.setUTCMonth(lastDay.getUTCMonth() + 1, 0);
  const end = selectedMonth === today.slice(0, 7) ? today : lastDay.toISOString().slice(0, 10);
  const rows = start > today ? [] : await dailyRows(start, end, query.userId ?? req.user.id, today);
  if (req.user.role !== 'admin') {
    for (const row of rows) delete row.correction_reason;
  }
  res.json({month: selectedMonth, today, data: rows});
});

attendanceSummaryRoutes.put('/correction/:userId/:date', adminOnly, async (req, res) => {
  const target = userId.parse(req.params.userId);
  const date = workDate.parse(req.params.date);
  const {status, reason, checkOut} = z.object({
    status: z.enum(['present', 'half_day', 'absent', 'leave', 'holiday', 'day_off']).nullable(),
    reason: z.string().trim().min(3).max(500),
    checkOut: z.string().datetime({offset: true}).optional()
  }).strict().parse(req.body);
  if (date > await businessDate()) {
    throw new AppError(400, 'FUTURE_DATE', 'Choose today or a previous date');
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = await client.query(
      'SELECT id FROM users WHERE id = $1 AND (created_at AT TIME ZONE $2)::date <= $3::date FOR UPDATE',
      [target, env.BUSINESS_TIMEZONE, date]);
    if (!user.rowCount) throw new AppError(404, 'NOT_FOUND', 'No user found for that date');
    if (checkOut) {
      const shift = await client.query(`
        UPDATE attendance SET check_out = $3::timestamptz
        WHERE user_id = $1 AND work_date = $2 AND check_out IS NULL
          AND $3::timestamptz >= check_in AND $3::timestamptz <= clock_timestamp()
      `, [target, date, checkOut]);
      if (!shift.rowCount) {
        throw new AppError(409, 'INVALID_CHECKOUT',
          'The shift must be open, and checkout must fall between check-in and now');
      }
    }
    if (status === null) {
      await client.query('DELETE FROM attendance_corrections WHERE user_id = $1 AND work_date = $2',
        [target, date]);
    } else {
      await client.query(`
        INSERT INTO attendance_corrections (user_id, work_date, status, reason, actor_id)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (user_id, work_date) DO UPDATE SET
          status = EXCLUDED.status, reason = EXCLUDED.reason,
          actor_id = EXCLUDED.actor_id, created_at = now()
      `, [target, date, status, reason, req.user.id]);
    }
    await client.query(`
      INSERT INTO attendance_correction_history (user_id, work_date, status, reason, actor_id, check_out)
      VALUES ($1, $2, $3, $4, $5, $6)
    `, [target, date, status, reason, req.user.id, checkOut ?? null]);
    await client.query('COMMIT');
    res.status(204).end();
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
});
