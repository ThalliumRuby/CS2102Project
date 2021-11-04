CREATE OR REPLACE PROCEDURE add_department (IN department_id INT, IN department_name VARCHAR(50) )
AS $$
BEGIN
    INSERT INTO departments(did, dname) VALUES (department_id , department_name);
END;
$$ LANGUAGE PLPGSQL;

-- When a department is removed, all employees in the department are removed too
CREATE OR REPLACE PROCEDURE remove_department (IN my_did INTEGER)
AS $$
DECLARE
curs CURSOR FOR (SELECT * FROM Employees WHERE did = my_did);
r1 RECORD;
replacing_did INTEGER ;
BEGIN
-- when a department is removed, employee transferred to the general department of 1
    SELECT MIN(did) INTO replacing_did FROM Departments;
    OPEN curs;
    LOOP
    FETCH curs INTO r1;
    EXIT WHEN r1 IS NULL;
    UPDATE Employees SET did = replacing_did
            WHERE CURRENT OF curs;
    MOVE curs;
    END LOOP;
    CLOSE curs;
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

-- Capacity of an meeting room can only be changed from today onwards, past dates have no effect
-- Only if eid passed is in manager and did matches the meeting room did, update is allowed
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

IF (SELECT COUNT(*) FROM Manager WHERE eid = my_id) >= 1
THEN
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
ELSE
RAISE EXCEPTION 'Only managers can update capacity';
END IF;
END;
$$ LANGUAGE PLPGSQL;

-- Ensure unique eid by increasing subsequent eid by 1
CREATE OR REPLACE PROCEDURE add_employee(IN employee_name VARCHAR(50), IN contact_num INTEGER, IN kind VARCHAR(10), IN department_id INTEGER)
AS $$
DECLARE
my_eid INT;
BEGIN
    SELECT MAX(eid) INTO my_eid FROM Employees;
	INSERT INTO Employees (eid, did, ename, contact, ekind)
		VALUES(my_eid +1, department_id, employee_name, contact_num, kind);
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


-- 2 of the core functions
CREATE OR REPLACE PROCEDURE book_room(IN floor_no INTEGER , IN room_no INTEGER , IN my_date DATE, IN start_hour INTEGER ,
IN end_hour INTEGER , IN employee_id INTEGER )
AS $$
DECLARE
isSick BOOL;
session_count INTEGER := 0;
insertion_count INTEGER := 0;
total_session INTEGER := end_hour - start_hour;
isAvailable BOOL := True;
meeting_date DATE := my_date;
booker_did INTEGER ;
room_did INTEGER ;
BEGIN
-- if the start time is greater than or equal to end time, not allowed
SELECT (end_hour - start_hour) INTO total_session;
SELECT did INTO booker_did FROM Employees WHERE eid = employee_id;
SELECT did INTO room_did FROM MeetingRooms WHERE floors = floor_no AND room = room_no;
IF (total_session <= 0)
THEN
RAISE EXCEPTION 'Invalid duration';
END IF;
-- if department of booker and room does not match, not allowed
IF NOT booker_did = room_did
THEN
RAISE EXCEPTION 'You can only book meeting rooms in your department';
END IF;
-- if the booker is not manager or senior, not allowed
IF NOT EXISTS (
    SELECT 1 FROM Senior WHERE eid = employee_id
    UNION
    SELECT 1 FROM Manager WHERE eid = employee_id
)
THEN
RAISE EXCEPTION 'You are not allowed to book';
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
LOOP
EXIT WHEN session_count = total_session;
IF EXISTS (
    SELECT 1 FROM sessions WHERE session_date = my_date AND session_time = (start_hour + (session_count))
                                 AND session_floor = floor_no AND session_room = room_no
)
THEN
isAvailable := FALSE ;
END IF;
session_count := session_count + 1;
END LOOP;

IF NOT (isAvailable IS TRUE )
THEN
RAISE EXCEPTION 'Session unavailable';
END IF;
-- insert all sessions into sessions table
LOOP
EXIT WHEN insertion_count = total_session;
INSERT INTO Sessions(
    session_date,
    session_time,
    session_floor,
    session_room,
    participant_id,
    booker_id,
    approver_id

) VALUES(
    my_date,
    start_hour + insertion_count,
    floor_no,
    room_no,
    employee_id,
    employee_id,
    NULL
        );
insertion_count := insertion_count + 1;
END LOOP;

END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE PROCEDURE unbook_room(IN floor_no INTEGER, IN room_no INTEGER, IN my_date DATE, IN start_hour INTEGER,
IN end_hour INTEGER, IN employee_id INTEGER)
AS $$
DECLARE
all_exist BOOL := TRUE;
session_count INTEGER := 0;
deletion_count INTEGER := 0;
total_session INTEGER := end_hour - start_hour;
BEGIN

IF (total_session <= 0)
THEN
RAISE EXCEPTION 'Invalid duration';
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

-- checks if the stated sessions exist
LOOP
EXIT WHEN session_count = total_session;
IF NOT EXISTS (
    SELECT 1 FROM sessions WHERE session_date = my_date
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
RAISE EXCEPTION 'Some session(s) do(es) not exist, please correct';
END IF;

LOOP
EXIT WHEN deletion_count = total_session;
DELETE FROM Sessions WHERE session_date = my_date
                             AND session_time = (start_hour + deletion_count)
                             AND session_floor = floor_no
                             AND session_room = room_no;
deletion_count := deletion_count + 1;
END LOOP;

END;
$$ LANGUAGE PLPGSQL;
