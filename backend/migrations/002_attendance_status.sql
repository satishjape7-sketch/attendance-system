CREATE TABLE attendance_corrections (
 user_id uuid NOT NULL REFERENCES users(id),
 work_date date NOT NULL,
 status text NOT NULL CHECK (status IN ('present', 'half_day', 'absent', 'leave', 'holiday', 'day_off')),
 reason text NOT NULL,
 actor_id uuid NOT NULL REFERENCES users(id),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (user_id, work_date)
);

CREATE TABLE attendance_correction_history (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 user_id uuid NOT NULL REFERENCES users(id),
 work_date date NOT NULL,
 status text CHECK (status IN ('present', 'half_day', 'absent', 'leave', 'holiday', 'day_off')),
 reason text NOT NULL,
 check_out timestamptz,
 actor_id uuid NOT NULL REFERENCES users(id),
 created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX audit_user_status_idx ON audit_events(target_id, created_at, id)
 WHERE action IN ('user.activated', 'user.deactivated');
