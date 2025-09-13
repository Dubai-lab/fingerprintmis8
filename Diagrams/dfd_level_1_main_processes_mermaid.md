# Fingerprint MIS - Level 1 Data Flow Diagram (Main Processes)

```mermaid
flowchart TD
    %% External entities
    Admin[👤 Admin]
    Instructor[👤 Instructor]
    Invigilator[👤 Invigilator]
    Security[👤 Security Personnel]
    Student[👤 Student]
    
    %% Main processes
    P1((1.0<br/>User Management<br/>Process))
    P2((2.0<br/>Course Management<br/>Process))
    P3((3.0<br/>Attendance Management<br/>Process))
    P4((4.0<br/>Fingerprint Processing<br/>Process))
    P5((5.0<br/>Report Generation<br/>Process))
    P6((6.0<br/>Security Verification<br/>Process))
    P7((7.0<br/>Authentication<br/>Process))
    
    %% Data stores
    D1[(D1<br/>Users)]
    D2[(D2<br/>Courses)]
    D3[(D3<br/>Attendance Records)]
    D4[(D4<br/>Fingerprint Templates)]
    D5[(D5<br/>Reports)]
    D6[(D6<br/>Sessions)]
    
    %% External device
    FDevice[(Fingerprint<br/>Device)]
    
    %% Admin flows
    Admin -->|Login Credentials| P7
    P7 -->|Authentication Status| Admin
    Admin -->|User Registration Data<br/>User Management Commands| P1
    P1 -->|User Management Results<br/>User Statistics| Admin
    Admin -->|Course Creation Data<br/>Course Management Commands| P2
    P2 -->|Course Management Results| Admin
    Admin -->|Report Requests| P5
    P5 -->|System Reports<br/>Attendance Reports| Admin
    
    %% Instructor flows
    Instructor -->|Login Credentials| P7
    P7 -->|Authentication Status| Instructor
    Instructor -->|Course Data<br/>Student Enrollment| P2
    P2 -->|Course Information<br/>Student Lists| Instructor
    Instructor -->|Attendance Session Data| P3
    P3 -->|Attendance Status<br/>Attendance Reports| Instructor
    Instructor -->|Report Requests| P5
    P5 -->|Course Analytics<br/>Attendance Reports| Instructor
    
    %% Invigilator flows
    Invigilator -->|Login Credentials| P7
    P7 -->|Authentication Status| Invigilator
    Invigilator -->|Exam/CAT Attendance Data| P3
    P3 -->|Attendance Reports<br/>Exam Session Data| Invigilator
    
    %% Security flows
    Security -->|Login Credentials| P7
    P7 -->|Authentication Status| Security
    Security -->|Verification Requests| P6
    P6 -->|Verification Results<br/>Access Decisions| Security
    
    %% Student flows
    Student -->|Registration Data| P1
    P1 -->|Registration Status| Student
    Student -->|Fingerprint Data| P4
    P4 -->|Enrollment Status| Student
    Student -->|Course Join Requests| P2
    P2 -->|Course Enrollment Status| Student
    
    %% Process to data store flows
    P1 <-->|User Data| D1
    P2 <-->|Course Data| D2
    P2 <-->|Session Data| D6
    P3 <-->|Attendance Records| D3
    P3 <-->|Session Information| D6
    P4 <-->|Fingerprint Templates| D4
    P5 <-->|Attendance Data| D3
    P5 <-->|User Data| D1
    P5 <-->|Course Data| D2
    P5 -->|Generated Reports| D5
    P6 <-->|User Verification Data| D1
    P6 <-->|Fingerprint Data| D4
    P7 <-->|Authentication Data| D1
    
    %% External device flows
    P4 <-->|Fingerprint Capture<br/>Template Generation<br/>Fingerprint Matching| FDevice
    P3 <-->|Attendance Verification| FDevice
    
    %% Styling
    classDef processStyle fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef entityStyle fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef datastoreStyle fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef deviceStyle fill:#fff3e0,stroke:#e65100,stroke-width:2px
    
    class P1,P2,P3,P4,P5,P6,P7 processStyle
    class Admin,Instructor,Invigilator,Security,Student entityStyle
    class D1,D2,D3,D4,D5,D6 datastoreStyle
    class FDevice deviceStyle
