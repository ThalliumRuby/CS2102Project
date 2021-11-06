CREATE OR REPLACE PROCEDURE add_department (IN department_id INT, IN department_name VARCHAR(50) )
AS $$
BEGIN
    INSERT INTO departments(did, dname) VALUES (department_id , department_name);
END;
$$ LANGUAGE PLPGSQL;

-- When a department is removed, all employees in the department are replaced to department 1
CREATE OR REPLACE PROCEDURE remove_department (IN my_did INTEGER)
AS $$
DECLARE
curs CURSOR FOR (SELECT * FROM Employees WHERE did = my_did);
r1 RECORD;
curs2 CURSOR FOR (SELECT * FROM MeetingRooms WHERE did = my_did);
r2 RECORD;
replacing_did INTEGER ;
BEGIN
-- when a department is removed, employee transferred to the general department of 1
    SELECT MIN(did) INTO replacing_did FROM Departments;
    OPEN curs;
    LOOP
    FETCH curs INTO r1;
    EXIT WHEN r1 IS NULL;
    UPDATE Employees SET did = replacing_did
            WHERE r1.did = did;
    END LOOP;
    CLOSE curs;
    OPEN curs2;
    LOOP
    FETCH curs2 INTO r2;
    EXIT WHEN r2 IS NULL;
    UPDATE MeetingRooms SET did = replacing_did
            WHERE r2.did = did;
    END LOOP;
    CLOSE curs2;
DELETE FROM departments WHERE did = my_did;
END;
$$ LANGUAGE PLPGSQL;


CREATE OR REPLACE PROCEDURE add_room( IN floor_no INTEGER, IN room_no INTEGER,
                                      IN room_name VARCHAR(50), IN capacity INTEGER, IN my_did INTEGER )
AS $$
BEGIN
    INSERT INTO meetingrooms
       (floors, room, rname, capacity, did, update_date)
       VALUES
       (floor_no, room_no, room_name, capacity, my_did, CURRENT_DATE );
END;
$$ LANGUAGE PLPGSQL;

-- Capacity of an meeting room can only be changed from today onwards, past and future dates have no effect
-- Only if eid passed is in manager and did matches the meeting room did, update is allowed
-- Only the lastest entry is stored if there are multiple updates with the same date on the same room
CREATE OR REPLACE PROCEDURE change_capacity(IN floor_no INTEGER, IN room_no INTEGER, IN new_capacity INTEGER, IN change_date DATE, IN my_id INTEGER )
AS $$
DECLARE
manager_did INTEGER ;
room_did INTEGER ;
BEGIN
SELECT did INTO manager_did FROM Employees WHERE eid = my_id;
SELECT did INTO room_did FROM MeetingRooms WHERE floors = floor_no AND room = room_no;
IF NOT (manager_did = room_did)
THEN
RAISE EXCEPTION 'Only manager from the same department may update capacity';
END IF;

IF NOT (SELECT COUNT(*) FROM Manager WHERE eid = my_id) >= 1
THEN
RAISE EXCEPTION 'Only managers can update capacity';
END IF;

IF (new_capacity <= 0)
THEN
RAISE EXCEPTION 'Invalid new capacity';
END IF;

IF NOT EXISTS (SELECT * FROM MeetingRooms WHERE floors = floor_no AND room = room_no)
THEN
RAISE EXCEPTION 'Invalid meeting room, please correct';
END IF;

INSERT INTO updates (
    dates,
    new_cap,
    floors,
    room,
    eid
) VALUES
    (change_date,
     new_capacity,
     floor_no,
     room_no,
     my_id
    )
    ON CONFLICT (dates, floors, room) DO UPDATE SET new_cap = new_capacity;
END;
$$ LANGUAGE PLPGSQL;

-- Ensure unique eid by increasing subsequent eid by 1
CREATE OR REPLACE PROCEDURE add_employee(IN employee_name VARCHAR(50), IN contact_num INTEGER, IN kind VARCHAR(10), IN department_id INTEGER)
AS $$
DECLARE
my_eid INT;
my_email VARCHAR (50);
BEGIN
    SELECT MAX(eid) INTO my_eid FROM Employees;
    my_eid := my_eid + 1;
    my_email := 'e'|| my_eid::varchar(50) || '%%@mycompany.com';
	INSERT INTO Employees (eid, did, ename, email, contact, ekind)
		VALUES(my_eid, department_id, employee_name, my_email, contact_num, kind);
END;
$$ LANGUAGE PLPGSQL;

-- Remove an employee by setting the resigned date
CREATE OR REPLACE PROCEDURE remove_employee(IN employee_id INTEGER, IN retired_date DATE)
AS $$
BEGIN
	UPDATE Employees SET resignedDate = retired_date WHERE eid = employee_id;
END;
$$ LANGUAGE PLPGSQL;

-- Trigger responsible for update meeting room capacity when there is a relevant record in updates
DROP TRIGGER IF EXISTS check_room_capacity ON Updates;

CREATE OR REPLACE FUNCTION update_cap()
  RETURNS TRIGGER
AS $$
BEGIN
    IF (NEW.dates = CURRENT_DATE ) THEN
        UPDATE MeetingRooms SET capacity = NEW.new_cap WHERE floors = NEW.floors AND room = NEW.room;
        UPDATE MeetingRooms SET update_date = NEW.dates WHERE floors = NEW.floors AND room = NEW.room;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER check_room_capacity AFTER
    INSERT OR UPDATE ON Updates
    FOR EACH ROW EXECUTE PROCEDURE update_cap();

-- Trigger responsible for removing future meetings with more participants than new capacity
DROP TRIGGER IF EXISTS remove_large_meeting ON MeetingRooms;

CREATE OR REPLACE FUNCTION remove_meeting()
  RETURNS TRIGGER
AS $$
DECLARE curs CURSOR FOR (SELECT session_date, session_time, session_floor, session_room, COUNT(*) AS people_count
    FROM (SELECT * FROM Sessions
    WHERE session_date >= NEW.update_date) AS all_sessions
    GROUP BY session_date, session_time, session_floor, session_room);
    r1 RECORD;
BEGIN
    OPEN curs;
    LOOP
    FETCH curs INTO r1;
    EXIT WHEN r1 IS NULL;
    IF r1.people_count > NEW.capacity
    THEN
    DELETE FROM sessions WHERE session_date = r1.session_date AND session_time = r1.session_time
                              AND session_floor = r1.session_floor AND session_room = r1.session_room;
    END IF;
    END LOOP;
    CLOSE curs;
    RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER remove_large_meeting AFTER
    INSERT OR UPDATE ON MeetingRooms
    FOR EACH ROW EXECUTE FUNCTION remove_meeting();

-- Trigger responsible for removing resigned employees from future meetings
DROP TRIGGER IF EXISTS remove_resigned_employee ON Employees;

CREATE OR REPLACE FUNCTION remove_from_future_meeting()
  RETURNS TRIGGER
AS $$
DECLARE
    leaving_date DATE;
    curs CURSOR FOR (SELECT * FROM sessions WHERE participant_id = NEW.eid
                 UNION SELECT * FROM Sessions WHERE booker_id = NEW.eid);
    r1 RECORD;
BEGIN
SELECT NEW.resignedDate INTO leaving_date;
IF NOT (leaving_date IS NULL)
THEN
    OPEN curs;
    LOOP
    FETCH curs INTO r1;
    EXIT WHEN r1 IS NULL;
    IF (r1.session_date >= leaving_date)
    THEN
    DELETE FROM sessions WHERE session_date = r1.session_date AND session_time = r1.session_time
                            AND session_floor = r1.session_floor AND session_room = r1.session_room
                            AND participant_id = NEW.eid;
    DELETE FROM sessions WHERE session_date = r1.session_date AND session_time = r1.session_time
                            AND session_floor = r1.session_floor AND session_room = r1.session_room
                            AND booker_id = NEW.eid;
    END IF;
    END LOOP;
    CLOSE curs;
END IF;
RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER remove_resigned_employee AFTER
    INSERT OR UPDATE ON Employees
    FOR EACH ROW EXECUTE FUNCTION remove_from_future_meeting();

-- Trigger responsible for preventing resigned employee from declare health
DROP TRIGGER IF EXISTS no_declare_health ON healthDeclaration;

CREATE OR REPLACE FUNCTION prevent_declaration()
  RETURNS TRIGGER
AS $$
DECLARE
leaving_date DATE;
BEGIN
SELECT resignedDate INTO leaving_date FROM Employees WHERE eid = NEW.eid;
IF NOT (leaving_date IS NULL)
THEN
    IF NEW.declareDate >= leaving_date
    THEN
    RAISE EXCEPTION 'The employee have left, cannot declare health';
    END IF;
    RETURN NEW;
END IF;
RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;


CREATE TRIGGER no_declare_health BEFORE
    INSERT OR UPDATE ON healthDeclaration
    FOR EACH ROW EXECUTE FUNCTION prevent_declaration();


-- 2 of the core functions
CREATE OR REPLACE PROCEDURE book_room(IN floor_no INTEGER , IN room_no INTEGER , IN my_date DATE, IN start_hour INTEGER ,
IN end_hour INTEGER , IN employee_id INTEGER )
AS $$
DECLARE
isSick BOOL;
session_count INTEGER ;
total_session INTEGER ;
isAvailable BOOL ;
leaving_date DATE ;
booker_did INTEGER ;
room_did INTEGER ;
BEGIN
-- if the start time is greater than or equal to end time, not allowed
total_session := end_hour - start_hour;
session_count := 0;
isAvailable := TRUE;
SELECT (end_hour - start_hour) INTO total_session;
SELECT did INTO booker_did FROM Employees WHERE eid = employee_id;
SELECT did INTO room_did FROM MeetingRooms WHERE floors = floor_no AND room = room_no;
SELECT resignedDate INTO leaving_date FROM Employees WHERE eid = employee_id;

IF (my_date < CURRENT_DATE )
THEN
RAISE EXCEPTION 'Date has passed, cannot book';
END IF;

IF NOT EXISTS (SELECT * FROM MeetingRooms WHERE floors = floor_no AND room = room_no)
THEN
RAISE EXCEPTION 'Invalid meeting room, please correct';
END IF;

IF NOT (leaving_date IS NULL) AND leaving_date <= CURRENT_DATE
THEN
RAISE EXCEPTION 'You have left, cannot book meeting';
END IF;

IF (total_session <= 0)
THEN
RAISE EXCEPTION 'Invalid duration, please check';
END IF;

IF (start_hour > 23 OR end_hour > 24)
THEN
RAISE EXCEPTION 'Invalid timing, please correct';
END IF;

-- if department of booker and room does not match, not allowed
IF NOT booker_did = room_did
THEN
RAISE EXCEPTION 'You can only book meeting rooms in your department';
END IF;
-- if the booker is not manager or senior, not allowed
IF NOT EXISTS (
    SELECT * FROM Senior WHERE eid = employee_id
    UNION
    SELECT * FROM Manager WHERE eid = employee_id
)
THEN
RAISE EXCEPTION 'You are not allowed to book, please ask a senior or manager';
END IF;
-- if the booker has not declared health, not allowed
SELECT fever INTO isSick FROM HealthDeclaration WHERE eid = employee_id AND declareDate = CURRENT_DATE ;
IF NOT FOUND
THEN
RAISE EXCEPTION 'You have not declared health today';
END IF;
-- if the booker has fever , not allowed
IF NOT (isSick IS FALSE)
THEN
RAISE EXCEPTION 'You must seek medical attention immediately';
END IF;
-- if the session at the time is already booked, not allowed
WHILE (session_count < total_session) LOOP
IF EXISTS (
    SELECT * FROM sessions WHERE session_date = my_date AND session_time = (start_hour + (session_count))
                                 AND session_floor = floor_no AND session_room = room_no
)
THEN
isAvailable := FALSE ;
END IF;
session_count := session_count + 1;
END LOOP;

IF NOT (isAvailable IS TRUE )
THEN
RAISE EXCEPTION 'Some session(s) unavailable';
END IF;
-- insert all sessions into sessions table
session_count := 0;
WHILE (session_count < total_session) LOOP
INSERT INTO Sessions(
    session_date,
    session_time,
    session_floor,
    session_room,
    participant_id,
    booker_id,
    is_approved,
    approver_id

) VALUES(
    my_date,
    start_hour + session_count,
    floor_no,
    room_no,
    employee_id,
    employee_id,
    NULL,
    NULL
        );
session_count := session_count + 1;
END LOOP;

END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE PROCEDURE unbook_room(IN floor_no INTEGER, IN room_no INTEGER, IN my_date DATE, IN start_hour INTEGER,
IN end_hour INTEGER, IN employee_id INTEGER)
AS $$
DECLARE
all_exist BOOL ;
session_count INTEGER ;
total_session INTEGER ;
BEGIN
all_exist := TRUE;
session_count := 0;
total_session := end_hour - start_hour;

IF (start_hour > 23 OR end_hour > 24)
THEN
RAISE EXCEPTION 'Invalid timing, please correct';
END IF;

IF (total_session <= 0)
THEN
RAISE EXCEPTION 'Invalid duration, please check';
END IF;

IF (my_date < CURRENT_DATE )
THEN
RAISE EXCEPTION 'Meeting has past, cannot unbook';
END IF;

IF NOT EXISTS (SELECT * FROM MeetingRooms WHERE floors = floor_no AND room = room_no)
THEN
RAISE EXCEPTION 'Invalid meeting room, please correct';
END IF;

-- checks if the stated sessions exist
WHILE (session_count < total_session) LOOP
IF NOT EXISTS (
    SELECT * FROM sessions WHERE session_date = my_date
                             AND session_time = (start_hour + session_count)
                             AND session_floor = floor_no
                             AND session_room = room_no
                             AND participant_id = employee_id
)
THEN
all_exist := FALSE;
END IF;
session_count := session_count + 1;
END LOOP;

IF NOT (all_exist IS TRUE)
THEN
RAISE EXCEPTION 'Some session(s) do(es) not exist or you are not the booker, please correct';
END IF;

IF employee_id NOT IN (SELECT booker_id FROM Sessions WHERE session_date = my_date
                                                        AND session_time = start_hour
                                                        AND session_floor = floor_no
                                                        AND session_room = room_no
                                                        AND participant_id = employee_id
)
THEN
RAISE EXCEPTION 'Only booker may unbook';
END IF;

session_count := 0;
WHILE (session_count < total_session) LOOP
DELETE FROM Sessions WHERE session_date = my_date
                             AND session_time = (start_hour + session_count)
                             AND session_floor = floor_no
                             AND session_room = room_no;
session_count := session_count + 1;
END LOOP;

END;
$$ LANGUAGE PLPGSQL;
