DROP TABLE IF EXISTS healthDeclaration, Employees, Departments, MeetingRooms, Sessions, Updates;

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
    resignedDate DATE,
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
    PRIMARY KEY (floors, room)
);

CREATE TABLE Sessions(
    session_date DATE,
    session_time TIME,
    PRIMARY KEY (session_date,session_time)
);

CREATE TABLE Updates(
    date DATE,
    new_cap INTEGER ,
    floors INTEGER ,
    room INTEGER ,
    PRIMARY KEY (date),
    FOREIGN KEY (floors, room) REFERENCES MeetingRooms(floors, room)
);
