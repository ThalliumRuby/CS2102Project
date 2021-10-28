CREATE TABLE Departments(
    did INTEGER,
    dname VARCHAR(50) NOT NULL,
    PRIMARY KEY (did)
);

CREATE TABLE MeetingRooms(
    floor INTEGER,
    room INTEGER,
    rname VARCHAR(50) NOT NULL,
    capacity INTEGER,
    update_date DATE,
    PRIMARY KEY (floor, room)
);

CREATE TABLE Sessions(
    session_date DATE,
    start_hour TIME,
    end_hour TIME,
    PRIMARY KEY (session_date,start_hour,end_hour),
    CONSTRAINT valid_sessiontime CHECK(start_hour <= end_hour)
);
