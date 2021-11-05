--f1
CREATE OR REPLACE FUNCTION non_compliance
  (start_date DATE, end_date DATE)
RETURNS TABLE(employee_ID INT, num BIGINT) AS $$
DECLARE 
num INT;
BEGIN
  num := (SELECT DATE_PART('day', end_date::timestamp - start_date::timestamp))+1;
  RETURN QUERY 
    SELECT eid, (num-count(declaredate)) AS missing
    FROM healthDeclaration 
    WHERE declaredate >= start_date 
    AND declaredate <= end_date
  AND eid IN (SELECT e.eid FROM Employees e WHERE resignedDate IS NULL)
    GROUP BY eid
    HAVING count(declaredate) < num
    ORDER BY missing DESC;
END;
$$ LANGUAGE plpgsql;

--f2
DROP FUNCTION view_booking_report(date,integer);
CREATE OR REPLACE FUNCTION view_booking_report
  (start_date DATE, employee_ID INT)
RETURNS TABLE(floor_number INT,room_number INT, sdate DATE, stime INT, approved BOOLEAN) AS $$
BEGIN
  RETURN QUERY 
    SELECT  DISTINCT session_floor, session_room, session_date, session_time, is_approved 
    FROM Sessions 
    WHERE session_date >= start_date 
    AND booker_id = employee_ID
    ORDER BY session_date ASC, session_time ASC;
END;
$$ LANGUAGE plpgsql;

--f3
CREATE OR REPLACE FUNCTION view_future_meeting
  (start_date DATE, employee_ID INT)
RETURNS TABLE(floor_number INT,room_number INT, sdate DATE, stime INT) AS $$
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
CREATE OR REPLACE FUNCTION view_manager_report
  (start_date DATE, employee_ID INT)
RETURNS TABLE(floor_number INT,room_number INT, sdate DATE, stime INT, eID INT) AS $$
BEGIN
  RETURN QUERY
      SELECT  DISTINCT session_floor, session_room, session_date, session_time, booker_id
      FROM Sessions 
      WHERE session_date >= start_date
	  AND is_approved IS NULL
	  AND employee_ID IN (SELECT m.eid FROM (SELECT * FROM manager) m)
      AND (SELECT e1.did FROM Employees e1 WHERE e1.eid = employee_ID) = (SELECT e2.did FROM Employees e2 WHERE e2.eid = booker_id)
      ORDER BY session_date ASC, session_time ASC;
END;
$$ LANGUAGE plpgsql;

--f1
CREATE OR REPLACE FUNCTION search_room
  (mincapacity INT, rdate Date, start_hour INT, end_hour INT)
RETURNS TABLE(floor_number INT, room_number INT, department_ID INT,  rcapacity INT) AS $$
BEGIN 
  RETURN QUERY
    SELECT floors, room, did, capacity
    FROM MeetingRooms
    WHERE capacity >= mincapacity
    AND NOT EXISTS(SELECT 1   	                                                                 
				   FROM Sessions s2
				   WHERE s2.session_date = rdate
				   AND s2.session_floor = floors
				   AND s2.session_room = room
				   AND s2.session_time IN (select generate_series(start_hour,end_hour-1)))
    ORDER BY capacity ASC;
END;
$$ LANGUAGE plpgsql;