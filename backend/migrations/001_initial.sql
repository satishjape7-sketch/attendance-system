CREATE TABLE users (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 name varchar(100) NOT NULL,
 email varchar(254) NOT NULL UNIQUE CHECK(email=lower(email)),
 password_hash text NOT NULL,
 role varchar(10) NOT NULL DEFAULT 'employee' CHECK(role IN ('admin','employee')),
 active boolean NOT NULL DEFAULT true,
 token_version integer NOT NULL DEFAULT 0,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE attendance (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES users(id),
 work_date date NOT NULL,
 check_in timestamptz NOT NULL DEFAULT now(),
 check_out timestamptz,
 UNIQUE(user_id,work_date),
 CHECK(check_out IS NULL OR check_out>=check_in)
);
CREATE UNIQUE INDEX one_open_shift ON attendance(user_id) WHERE check_out IS NULL;
CREATE INDEX attendance_date_idx ON attendance(work_date,user_id);
CREATE TABLE audit_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 actor_id uuid REFERENCES users(id),
 action text NOT NULL,
 target_id uuid,
 created_at timestamptz NOT NULL DEFAULT now()
);
