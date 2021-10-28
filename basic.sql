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

