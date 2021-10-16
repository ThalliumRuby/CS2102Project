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
    session_time TIME,
    PRIMARY KEY (session_date,session_time),
);
