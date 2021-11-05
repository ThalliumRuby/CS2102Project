CREATE OR REPLACE FUNCTION declare_health
(e_id  INT, de_date DATE, tem NUMERIC)
RETURNS VOID AS $$
DECLARE
fever_statue BOOLEAN := FALSE;
BEGIN
	IF EXISTS (SELECT * FROM healthDeclaration WHERE eid = e_id AND declaredate = de_date) THEN
	DELETE
	FROM healthDeclaration
	WHERE eid = e_id AND declaredate = de_date;
	END IF;
	IF tem > 37.5 THEN
	fever_statue = TRUE;
	END IF;
	INSERT INTO healthDeclaration(declareDate, temp, fever, eid) VALUES (de_date, tem, fever_statue, e_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_fever()
RETURNS TRIGGER AS $$

BEGIN
	
	IF NEW.fever = TRUE THEN
	RAISE NOTICE 'Run contact tracing on employee % on date %', NEW.eid, NEW.declareDate;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS non_fever on healthDeclaration;

CREATE TRIGGER  non_fever
BEFORE INSERT ON healthDeclaration
FOR EACH ROW EXECUTE FUNCTION check_fever();


CREATE OR REPLACE FUNCTION contact_tracing
DECLARE
past_day DATE := fever_date - 3;
d DATE;
BEGIN
	FOR d IN 0..7 LOOP
		DELETE
		FROM Sessions
		WHERE participant_id = e_id AND session_date = fever_date + d;
		END LOOP;

	RETURN QUERY
		WITH attend_meeting AS(
			SELECT session_date AS s_date, session_time AS s_time, session_floor AS s_floor, session_room AS s_room
			FROM Sessions
			WHERE participant_id = e_id AND session_date IN (past_day, past_day + 1, past_day + 2))
		SELECT DISTINCT(participant_id)
		FROM Sessions s JOIN attend_meeting m ON s.session_floor = m.s_floor AND s.session_room = m.s_room AND s.session_date = m.s_date AND s.session_time = m.s_time
		WHERE s.participant_id <> e_id AND s.is_approved = TRUE;


END;

$$ LANGUAGE plpgsql;


----------------------------------------------------------------
-- the join_meeting fucntion
----------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_join()
RETURNS TRIGGER AS $$
DECLARE
count INT;
max_cap INT;
BEGIN
	IF NEW.is_approved = TRUE THEN
		RAISE NOTICE 'This session has been approved, so you are not allowed to joing the meeting.';
		RETURN NULL;
	END IF;

	IF NEW.is_approved = FALSE THEN
		RAISE NOTICE 'This session has been removed, so you are not allowed to joing the meeting.';
		RETURN NULL;
	END IF;

	SELECT new_cap INTO max_cap
	FROM Updates U
	WHERE dates <= CURRENT_DATE 
	AND U.floors = NEW.session_floor 
	AND U.room = NEW.session_room
	ORDER BY dates DESC
	LIMIT 1;


	SELECT COUNT(s.participant_id) INTO count
	FROM Sessions s
	WHERE s.session_floor = NEW.session_floor 
	AND s.session_room = NEW.session_room 
	AND s.session_date = NEW.session_date 
	AND s.session_time = NEW.session_time;

	IF count = max_cap THEN
		RAISE NOTICE 'The meeting is full.';
		RETURN NULL;
	ELSE
		RETURN NEW;
	END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS can_join on Sessions;		

CREATE TRIGGER can_join
BEFORE INSERT ON Sessions 
FOR EACH ROW EXECUTE FUNCTION check_join();





CREATE OR REPLACE FUNCTION join_meeting
(floor_num INT, r_num INT, m_date DATE, s_time INT, e_time INT, e_id INT)
RETURNS VOID AS $$
DECLARE 
e_hour INT := e_time - 1;
e_fever BOOLEAN := FALSE;
exist_session Sessions%ROWTYPE;
BEGIN

	IF m_date < CURRENT_DATE THEN
	RAISE NOTICE 'You cannot join a meeting in the past.';
	END IF;

	IF NOT EXISTS(SELECT * FROM healthDeclaration WHERE eid = e_id AND declareDate = CURRENT_DATE) THEN
	RAISE NOTICE 'You haven not declare youe temperature for today.';
	RETURN;
	END IF;

	SELECT h.fever INTO e_fever
	FROM healthDeclaration h
	WHERE h.eid = e_id
	AND h.declareDate = CURRENT_DATE;

	IF e_fever = TRUE THEN
	RAISE NOTICE 'You should go to see a doctor!';
	RETURN;
	END IF;


	
	IF e_fever = FALSE THEN
		FOR hour IN s_time..e_hour LOOP

			IF NOT EXISTS(SELECT * 
							FROM Sessions
							WHERE session_floor = floor_num 
							AND session_room = r_num 
							AND session_date = m_date 
							AND session_time = hour) THEN
			RAISE NOTICE 'The meeting on %:00 does not exist', hour;
			CONTINUE;
			END IF;

			SELECT * INTO exist_session
			FROM Sessions
			WHERE session_floor = floor_num 
			AND session_room = r_num 
			AND session_date = m_date 
			AND session_time = hour
			LIMIT 1;

			INSERT INTO Sessions VALUES (m_date, hour, floor_num, r_num, e_id, exist_session.booker_id, exist_session.is_approved, exist_session.approver_id);
		END LOOP;
	END IF;
END;

$$ LANGUAGE plpgsql;
-------------------------------------------------------------------------------


---------------------------------------------------------------------------
-- leave_meeting function
--------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE leave_meeting
(floor_num INT, r_num INT, m_date DATE, s_time INT, e_time INT, e_id INT)
AS $$
DECLARE
temp_e INT := e_time - 1;
old_session Sessions%ROWTYPE;
BEGIN
	FOR hour IN s_time..temp_e LOOP
		SELECT * INTO old_session
			FROM Sessions
			WHERE session_floor = floor_num 
			AND session_room = r_num 
			AND session_date = m_date 
			AND session_time = hour
			AND participant_id = e_id;
		
		IF old_session.is_approved = TRUE THEN
		RAISE NOTICE 'You are not allowed to leave an approved meeting.';
		CONTINUE;
		END IF;

		DELETE
		FROM Sessions
		WHERE session_floor = floor_num AND session_room = r_num AND session_date = m_date AND session_time = hour AND participant_id = e_id;
	END LOOP;
END;
$$ LANGUAGE plpgsql;
-------------------------------------------------------------------------------



-----------------------------------------------------------------------------
--approve_meeting function
-----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION approve_meeting
(floor_num INT, r_num INT, m_date DATE, s_hour INT, e_hour INT, a_id INT)
RETURNS VOID AS $$
DECLARE
temp_e INT:= e_hour - 1;
b_did INT;
a_did INT;
BEGIN
	IF a_id NOT IN (SELECT eid FROM Manager) THEN
		RAISE NOTICE 'You are not allowed to approved this meeting.';
		RETURN;
	END IF;

	SELECT did INTO a_did 
	FROM Manager
	WHERE eid = a_id;

	FOR hour in s_hour..temp_e LOOP
		SELECT e.did INTO b_did
		FROM Sessions s JOIN Employees e ON s.booker_id = e.eid
		WHERE s.session_floor = floor_num AND s.session_room = r_num AND s.session_date = m_date AND s.session_time = hour;

		IF b_did <> a_did THEN
		RAISE NOTICE 'The session on %:00 is booked by employee from other department, you cannot approve it.', hour;
		CONTINUE;
		END IF;


		UPDATE Sessions SET is_approved = TRUE 
		WHERE session_floor = floor_num 
		AND session_room = r_num 
		AND session_date = m_date 
		AND session_time = hour;

		UPDATE Sessions SET approver_id = a_id
		WHERE session_floor = floor_num 
		AND session_room = r_num 
		AND session_date = m_date 
		AND session_time = hour;
	END LOOP;
END;

$$ LANGUAGE plpgsql;

