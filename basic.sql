CREATE OR REPLACE PROCEDURE add_department (IN department_id INT, IN department_name VARCHAR(50) )
AS $$
INSERT INTO departments VALUES (department_id , department_name)
$$ LANGUAGE sql ;

-- When a department is removed, all employees in the department are removed too
CREATE OR REPLACE PROCEDURE remove_department (IN my_did INTEGER)
AS $$
DECLARE curs CURSOR FOR (SELECT * FROM Employees WHERE did = my_did);
        r_row RECORD;
BEGIN
    OPEN curs;
    FOR r_row IN curs LOOP
        UPDATE Employees SET resignedDate = CURRENT_DATE
            WHERE CURRENT OF curs;
    END LOOP;
    CLOSE curs;
DELETE FROM departments WHERE did = my_did;
END;
$$ LANGUAGE sql ;


CREATE OR REPLACE PROCEDURE add_room( IN floor_no INTEGER, IN room_no INTEGER, IN room_name VARCHAR(50), IN capacity INTEGER)
AS $$
INSERT INTO meetingrooms
       (floor, room, rname, capacity)
       VALUES
       (floor_no, room_no, room_name, capacity)
$$ LANGUAGE sql ;

-- Capacity of an meeting room can only be changed from today onwards, past dates have no effect
-- Only if eid passed is in manager and did matches the meeting room did, update is allowed
CREATE OR REPLACE PROCEDURE change_capacity(IN floor_no INTEGER, IN room_no INTEGER, IN new_capacity INTEGER, IN change_date DATE, IN my_id INTEGER )
AS $$
BEGIN
IF EXISTS (SELECT 1 FROM Manager WHERE eid = my_id)
THEN
INSERT INTO updates VALUES
    (change_date,
     new_capacity,
     floor_no,
     room_no,
     my_id
    )
    ON CONFLICT (date, floors, room) DO UPDATE SET new_capacity = new_cap;
    new_cap = capacity;
ELSE
RAISE EXCEPTION 'Only managers can update capacity';
END IF;
END;
$$ LANGUAGE sql;

-- Ensure unique eid by increasing subsequent eid by 1
CREATE OR REPLACE PROCEDURE add_employee(IN employee_name VARCHAR(50), IN contact_num INTEGER, IN kind VARCHAR(10), IN department_id INTEGER)
AS $$
	INSERT INTO Employees (eid, did, ename, contact, ekind)
		VALUES(max(eid)+1, department_id, employee_name, contact_num, kind);
		
$$ LANGUAGE sql;

-- Remove an employee by setting the resigned date
CREATE OR REPLACE PROCEDURE remove_employee(IN employee_id INTEGER, IN retired_date DATE)
AS $$
	UPDATE Employees
	SET resignedDate = retired_date
    WHERE eid = employee_id;

$$ LANGUAGE sql;

-- Trigger responsible for update meeting room capacity when there is a relevant record in updates
CREATE TRIGGER check_room_capacity
    AFTER INSERT OR UPDATE ON Updates
    FOR EACH ROW EXECUTE FUNCTION update_cap();

CREATE OR REPLACE FUNCTION update_cap()
RETURN TRIGGER AS $$
BEGIN
IF (NEW.change_date = CURRENT_DATE ) THEN
    UPDATE MeetingRooms SET capacity = NEW.new_capacity WHERE floors = NEW.floor_no AND room = NEW.room_no;
    UPDATE MeetingRooms SET update_date = NEW.change_date WHERE floors = NEW.floor_no AND room = NEW.room_no;
END IF;
END;
$$ LANGUAGE sql;
