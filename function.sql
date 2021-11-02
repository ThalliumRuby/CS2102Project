CREATE OR REPLACE FUNCTION declear_health
(e_id  INT, de_date DATE, tem NUMERIC)
RETURNS VOID AS $$
DECLARE
fever_statue BOOLEAN := FALSE
BEGIN
	IF tem > 37.5 THEN
	fever_statue = TURE
	END IF;
	INSERT INTO healthDeclaration(declareDate, temp, fever, eid) VALUES (de_date, tem, fever_statue, e_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER AS non_fever
BEFORE INSERT ON healthDeclaration
FOR EACH ROW EXECUTE FUNCTION check_fever();

CREATE OR REPLACE FUNCTION check_fever()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.fever_statue = TRUE THEN
	RAISE NOTICE 'Run contact tracing on employee' || NEW.eid || 'on date' || NEW.declareDate;
	END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION contact_tracing
(e_id INT, fever_date DATE)
RETURNS TABLE(close_contact_id INT) AS $$
DECLARE
past_day DATE := DATEADD(DAY, -3, GETDATE(fever_date));
d DATE;
BEGIN
	FOR d IN fever_date..DATEADD(DAY, 7, fever_date) LOOP
		DELETE
		FROM Sessions
		WHERE participant_id = e_id AND session_date = d;

	RETURN QUERY
		WITH attend_meeting AS(
			SELECT session_date AS s_date, session_time AS s_time, session_floor AS s_floor, session_room AS s_room
			FROM Sessions
			WHERE participant_id = e_id AND session_date IN (past_day, DATEADD(DAY,1,past_day), DATEADD(DAY,2,past_day)))
		SELECT UNIQUE(participant_id)
		FROM Sessions s JOIN attend_meeting m ON s.session_floor = m.s_floor AND s.session_room = m.s_room AND s.session_date = m.s_date AND s.session_time = m.s_time
		WHERE s.participant_id <> e_id AND a.is_approved = TURE;


END;
$$ LANGUAGE plpgsql;

----------------------------------------------------------------
-- the join_meeting fucntion
----------------------------------------------------------------

	
CREATE OR REPLACE TRIGGER AS max_total
BEFORE INSERT ON Sessions 
FOR EACH ROW EXECUTE FUNCTION check_join()

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

	SELECT MAX(new_cap) INTO max_cap
	FROM Updates U
	GROUP BY(U.floors, U.room)
	HAVING U.floors = NEW.session_floor AND U.room = NEW.session_room;


	SELECT COUNT(s.participant_id) INTO count
	FROM Sessions s
	WHERE s.session_floor = NEW.session_floor AND s.session_room = NEW.session_room AND s.session_date = NEW.session_date AND s.session_time = NEW.session_time;

	IF count = max_cap THEN
		RETURN NULL;
	ELSE
		RETURN NEW;
	END IF;
END;
$$ LANGUAGE plpgsql;
	
	
	
-- create a  trigger to chack the total participants
CREATE OR REPLACE FUNCTION join_meeting
(floor_num INT, r_num INT, m_date DATE, s_time INT, e_time INT, e_id INT)
RETURNS VOID AS $$
-- 要不要判断这个employee 有无fever,: 要，project p2 booking procedure
DECLARE 
e_hour INT := e_tiem - 1;
e_fever BOOLEAN := FALSE;
bookerId INT;
approve_statue BOOLEAN := NULL;
BEGIN
--contact tracing said that a fever people is not allowed to join the meeting in the future 7 days, so I should check the fever in the past seven days?
-- no because the day he joined the meeting may not be the day the meeting will hold, so maybe just check the temperature for the recoreded last day
-- then do the other job in contact tracing part
	SELECT h.fever INTO e_fever
	FROM healthDeclaration h
	WHERE h.eid = e_id
	ORDER BY h.declareDate DESC
	LIMIT 1;
	
	IF e_fever = FALSE THEN
		FOR hour IN s_time..e_hour LOOP
			SELECT s.booker_id INTO bookerId, s.is_approved INTO approve_statue
			FROM Sessions s
			WHERE s.session_floor = floor_num AND s.session_room = r_num AND s.session_date = m_date AND s.session_time = hour;

			INSERT INTO Sessions VALUES (m_date, hour, floor_num, r_num, e_id, bookId, approve_statue);
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
DELCARE
temp_e INT := e_time - 1
BEGIN
	FOR hour IN s_time..temp_e LOOP
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
	DECLAER 
	temp_e INT:= e_hour - 1;
	b_did INT;
	a_did INT;
	BEGIN
	IF a_id NOT IN (SELECT eid FROM Manager) THEN
		RAISE NOTICE 'You are not allowed to approved this meeting.' 
		RETURN;
	END IF;

	SELECT did INTO a.did 
	FROM Manager
	WHERE eid = a_id;

	FOR hour in s_hour..temp_e LOOP
		SELECT e.did INTO b_did
		FROM Sessions s JOIN Employees e ON s.booker_id = e.eid
		WHERE s.session_floor = floor_num AND s.session_room = r_num AND s.session_date = m_date AND s.session_time = hour;

		CONTINUE WHEN b_did <> a.did;

		UPDATE Sessions SET is_approved = TURE WHERE session_floor = floor_num AND session_room = r_num AND session_date = m_date AND session_time = hour;
	END LOOP;
END;
$$ LANGUAGE plpgsql;

--f1
--capacity?
CREATE OR REPLACE FUNCTION search_room
  （IN mincapacity INT, IN rdate Date, IN start_hour INT, IN end_hour INT)
RETURNS TABLE(floor_number INT, room_number INT, department_ID INT,  rcapacity INT) AS $$
DECLARE
temp INT := 0, d INT, duration INT[];
BEGIN 
  duration := ARRAY[start_hour:end_hour-1];
  RETURN QUERY
    SELECT m.session_floor, m.session_room, m.did, m.capacity
    FROM MeetingRooms m --LEFT JOIN Sessions  s
    --ON (s.session_floor = m.floors
    --AND s.session_room = m.room)
    AND m.capacity >= mincapacity
    AND --((NOT EXISTS(SELECT 1
    	            --FROM Sessions s1
    	            --WHERE s1.session_date = rdate
    	            --AND s1.session_floor = s.session_floor
    	            --AND s1.session_floor = s.session_room)  OR
    NOT EXISTS(SELECT 1   	                                                                 
               FROM Sessions s2
               WHERE s2.session_date = rdate
               AND s2.session_floor = m.floors
               AND s2.session_room = m.room
               AND s2.session_time IN duration))
    ORDER BY m.capacity ASC;
END;
$$ LANGUAGE plpgsql;


--Basic
--f5
CREATE OR REPLACE FUNCTION add_employee
  (IN ename INT, IN phone INT, INT kind varchar(10), IN department_ID INT)
RETURNS VOID AS $$
  new_eid INT := 0;
BEGIN 
  INSERT INTO Employees(eid, ename, contact, type, did) VALUES (DEFAULT, ename, phone, kind, department_ID) RETURNING eid INTO new_eid;
  UPDATE Employees SET email = new_eid || '@cs2102.com' WHERE eid = new_eid;
END;
$$ LANGUAGE plpgsql;

--f6
CREATE OR REPLACE FUNCTION remove_employee
  (IN removed_eid INT, IN last_date Date)
BEGIN 
  UPDATE Employees SET resignedDate = last_date WHERE eid = removed_eid;
END;
$$ LANGUAGE plpgsql;

--Admin
--f1
CREATE OR REPLACE FUNCTION non_compliance
  (start_date DATE, end_date DATE)
RETURNS TABLE(employee_ID INT, num INT) AS $$
BEGIN
  RETURN QUERY 
    SELECT eid, count(date) --INTO employee_ID, days 
    FROM Employees 
    WHERE date >= start_date 
    AND date <= end_date
    GROUP BY eid
    HAVING count(date) < (end_date - start_date + 1)
    ORDER BY count(date) DESC;
END;
$$ LANGUAGE plpgsql;

--f2
CREATE OR REPLACE FUNCTION view_booking_report
  (start_date DATE, employee_ID INT)
RETURNS TABLE(floor_number INT,room_number INT, session_date DATE, start_hour INT, approved BOOLEAN) AS $$
BEGIN
  RETURN QUERY 
    SELECT  session_floor, session_room, session_date, session_time, is_approved 
    FROM Sessions 
    WHERE session_date >= start_date 
    AND booker_id = employee_ID
    ORDER BY session_date ASC, session_time ASC;
END;
$$ LANGUAGE plpgsql;

--f3
CREATE OR REPLACE FUNCTION view_future_meeting
  (start_date DATE, employee_ID INT)
RETURNS TABLE(floor_number INT,room_number INT, session_date DATE, start_hour INT) AS $$
BEGIN
  RETURN QUERY 
    SELECT  session_floor, session_room, session_date, session_time
    FROM Sessions 
    WHERE session_date >= start_date 
    AND participant_id = employee_ID
    AND is_approved
    ORDER BY session_date ASC, session_time ASC;
END;
$$ LANGUAGE plpgsql;

--f4
--same department, employee id?
CREATE OR REPLACE FUNCTION view_manager_report
  (start_date DATE, employee_ID INT)
RETURNS TABLE(floor_number INT,room_number INT, session_date DATE, start_hour INT, employee_ID INT) AS $$
BEGIN
  IF employee_ID in (SELECT eid FROM Manager()) THEN RETURN NULL
  ELSE 
    RETURN QUERY 
      SELECT  distinct(session_floor, session_room, session_date, session_time, booker_id)
      FROM Sessions 
      WHERE session_date >= start_date 
      AND (SELECT did FROM Employees WHERE eid = employee_ID) = (SELECT did FROM Employees WHERE eid = booker_id)
      ORDER BY session_date ASC, session_time ASC;
END;
$$ LANGUAGE plpgsql;