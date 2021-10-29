CREATE OR REPLACE PROCEDURE add_department (IN department_id INT, IN department_name VARCHAR(50) )
AS $$
INSERT INTO departments VALUES (department_id , department_name)
$$ LANGUAGE sql ;

CREATE OR REPLACE PROCEDURE remove_department (IN my_did INTEGER)
AS $$
DELETE FROM departments WHERE did = my_did
$$ LANGUAGE sql ;

CREATE OR REPLACE PROCEDURE add_room( IN floor_no INTEGER, IN room_no INTEGER, IN room_name  VARCHAR(50), IN capacity INTEGER )
AS $$
INSERT INTO meetingrooms
       (floor, room, rname, capacity)
       VALUES
       (floor_no, room_no, room_name, capacity)
$$ LANGUAGE sql ;

CREATE OR REPLACE PROCEDURE change_capacity(IN floor_no INTEGER, IN room_no INTEGER, IN new_capacity INTEGER, IN change_date DATE)
AS $$

	UPDATE MeetingRooms
	SET capacity = capacity + new_capacity, update_date = change_date
	WHERE floor_no = floors AND room_no = room;

$$ LANGUAGE sql;

CREATE OR REPLACE PROCEDURE add_employee(IN employee_name VARCHAR(50), IN contact_num INTEGER, IN kind VARCHAR(10), IN department_id INTEGER)
AS $$
	INSERT INTO Employees (eid, did, ename, contact, ekind)
		VALUES(max(eid)+1, department_id, employee_name, contact_num, kind);
		
$$ LANGUAGE sql;

CREATE OR REPLACE PROCEDURE remove_employee(IN employee_id INTEGER, IN retired_date DATE)
AS $$
	UPDATE Employees
	SET resignedDate = retired_date;

$$ LANGUAGE sql;
