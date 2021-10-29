DROP TABLE IF EXISTS healthDeclaration, Employees, Departments, MeetingRooms, Sessions, Updates;

DROP VIEW IF EXISTS Junior, Senior, Manager;

CREATE TABLE healthDeclaration(
    declareDate DATE,
    temp NUMERIC(3, 1) NOT NULL,
    fever BOOLEAN NOT NULL DEFAULT FALSE,
    eid INTEGER,
    FOREIGN KEY (eid) REFERENCES Employees(eid),
    PRIMARY KEY (eid, date)
);

CREATE TABLE Employees(
    eid INTEGER,
    did INTEGER,
    ename VARCHAR(50) NOT NULL,
    email VARCHAR(50),
    contact VARCHAR(50) NOT NULL,
    resignedDate DATE DEFAULT NULL,
    ekind VARCHAR(10),
    PRIMARY KEY (eid),
    FOREIGN KEY (did) REFERENCES Departments(did)
    CHECK (type IN {'Junior', 'Senior', 'Manager'})
);

CREATE TABLE Departments(
    did INTEGER,
    dname VARCHAR(50) NOT NULL,
    PRIMARY KEY (did)
);

CREATE TABLE MeetingRooms(
    floors INTEGER,
    room INTEGER,
    rname VARCHAR(50) NOT NULL,
    capacity INTEGER,
    update_date DATE,
    did INTEGER ,
    PRIMARY KEY (floors, room),
    FOREIGN KEY (did) REFERENCES Departments(did)
);

CREATE TABLE Sessions(
    session_date DATE,
    session_time TIME,
    session_floor INTEGER,
    session_room INTEGER,
    participant_id INTEGER ,
    booker_id INTEGER NOT NULL,
    is_approved BOOLEAN DEFAULT NULL,
    PRIMARY KEY (session_date,session_time, session_floor, session_room, participant_id),
    FOREIGN KEY(session_floor, session_room) REFERENCES MeetingRooms(floors, room),
    FOREIGN KEY(participant_id) REFERENCES Employees(eid),
    FOREIGN KEY(booker_id) REFERENCES Employees(eid)
);

CREATE TABLE Updates(
    date DATE,
    new_cap INTEGER ,
    floors INTEGER ,
    room INTEGER ,
    eid INTEGER NOT NULL,
    PRIMARY KEY (date),
    FOREIGN KEY (floors, room) REFERENCES MeetingRooms(floors, room),
    FOREIGN KEY(eid) REFERENCES Employees(eid)
);

CREATE OR REPLACE VIEW Junior AS(
    SELECT
                     eid, did
              FROM
                     Employees
              WHERE
                     ekind = 'Junior'
);

CREATE OR REPLACE VIEW Senior AS(
    SELECT
                     eid, did
              FROM
                     Employees
              WHERE
                     ekind = 'Senior'
);

CREATE OR REPLACE VIEW Manager AS(
    SELECT
                     eid, did
              FROM
                     Employees
              WHERE
                     ekind = 'Manager'
);