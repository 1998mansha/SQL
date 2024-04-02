--Mansha Gupta
-- 230 Phase 3 Project
-- Research

-- “How can students find available projects for them to join?” 

create proc spProjectFinder 
    @studentID int,
	@major nvarchar(50)
as
begin
    declare @studentGPA decimal(3,2)
    declare @projectCount int
--Get student's GPA
    select @studentGPA=StudentGPA
    from Research.Student
    where StudentID=@studentID
--Check if student is eligible based on GPA
    if @studentGPA < 2.75
    begin
        throw 50001, 'The student is not eligible to participate in any projects due to a low GPA.', 1
        return
    end
--Check if the given major has projects
    select @projectCount=count(p.ProjectID)
    from Research.Project p join Research.Company c on p.CompanyID=c.CompanyID join Research.StudentProject sp on p.ProjectID=sp.ProjectID
    where p.ProjectStartDate <= getdate() and p.ProjectType=@major and sp.EndDate > getdate()--Check if the project is active

    if @projectCount=0
    begin 
        throw 50002, 'The given major currently has no projects.', 2
        return
    end 
--Get available projects with available spots
    select p.ProjectID, p.ProjectType, count(sp.StudentID) as 'Number Of Members'
    from Research.Project p left join Research.StudentProject sp on p.ProjectID=sp.ProjectID
    where p.ProjectType=@major
    group by p.ProjectID, p.ProjectType
    having count(sp.StudentID)<5 --Limit to projects with available spots
    order by p.ProjectID

end


--- “How to find out the status of a given project?”

ALTER PROCEDURE spProjectStatus
    @ProjectTitle NVARCHAR(100)
AS
BEGIN
    DECLARE @CurrentDate DATE = GETDATE(); 

    IF EXISTS (SELECT 1 FROM Research.Project WHERE ProjectTitle = @ProjectTitle)
    BEGIN
        SELECT
            P.ProjectID,
            P.ProjectType,
            P.ProjectTitle,
            CASE
                WHEN SP.EndDate < @CurrentDate THEN 'Finished'
                WHEN SP.JoinDate <= @CurrentDate AND SP.EndDate >= @CurrentDate THEN 'Active'
                WHEN SP.JoinDate > @CurrentDate THEN 'Upcoming'
            END AS ProjectStatus
        FROM
            Research.Project AS P
        INNER JOIN
            Research.StudentProject AS SP ON P.ProjectID = SP.ProjectID
        WHERE
            P.ProjectTitle = @ProjectTitle;
    END
    ELSE
    BEGIN
        PRINT 'Error: Project title does not exist';
    END
END;

EXEC spProjectStatus 'Increase Engagement';
EXEC spProjectStatus 'Uncommon Project';



-- “Based on knowing a student or advisor's name, how do we find the projects they are assigned to?”

ALTER PROCEDURE spProjectAssignment
    @PersonName NVARCHAR(100)
AS
BEGIN
    IF EXISTS (SELECT 1 FROM Research.Student WHERE CONCAT(StudentName, ' ', StudentLName) = @PersonName)
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM Research.Student AS S
                       LEFT JOIN Research.StudentProject AS SP ON S.StudentID = SP.StudentID
                       WHERE CONCAT(S.StudentName, ' ', S.StudentLName) = @PersonName AND SP.ProjectID IS NOT NULL)
        BEGIN
            PRINT 'Not assigned to a project';
        END
        ELSE
        BEGIN
            SELECT 
                SP.ProjectID,
                P.ProjectType,
                P.ProjectTitle,
                'Assigned' AS AssignmentStatus
            FROM Research.Student AS S
            LEFT JOIN Research.StudentProject AS SP ON S.StudentID = SP.StudentID
            LEFT JOIN Research.Project AS P ON SP.ProjectID = P.ProjectID
            WHERE CONCAT(S.StudentName, ' ', S.StudentLName) = @PersonName;
        END
    END
    ELSE IF EXISTS (SELECT 1 FROM Research.Advisor WHERE CONCAT(FName, ' ', LName) = @PersonName)
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM Research.Advisor AS A
                       LEFT JOIN Research.Comment AS C ON A.AdvisorID = C.AdvisorID
                       LEFT JOIN Research.Project AS P ON C.ProjectID = P.ProjectID
                       LEFT JOIN Research.StudentProject AS SP ON P.ProjectID = SP.ProjectID
                       WHERE CONCAT(A.FName, ' ', A.LName) = @PersonName AND P.ProjectID IS NOT NULL)
        BEGIN
            PRINT 'Not assigned to a project';
        END
        ELSE
        BEGIN
            SELECT 
                CASE 
                    WHEN P.ProjectID IS NULL THEN NULL 
                    ELSE SP.ProjectID 
                END AS ProjectID,
                CASE 
                    WHEN P.ProjectType IS NULL THEN 'Not assigned to a project' 
                    ELSE P.ProjectType 
                END AS ProjectType,
                CASE 
                    WHEN P.ProjectTitle IS NULL THEN 'Not assigned to a project' 
                    ELSE P.ProjectTitle 
                END AS ProjectTitle,
                CASE 
                    WHEN P.ProjectID IS NOT NULL THEN 'Assigned' 
                    ELSE 'Not assigned to a project' 
                END AS AssignmentStatus
            FROM Research.Advisor AS A
            LEFT JOIN Research.Comment AS C ON A.AdvisorID = C.AdvisorID
            LEFT JOIN Research.Project AS P ON C.ProjectID = P.ProjectID
            LEFT JOIN Research.StudentProject AS SP ON P.ProjectID = SP.ProjectID
            WHERE CONCAT(A.FName, ' ', A.LName) = @PersonName;
        END
    END
    ELSE
    BEGIN
        PRINT 'Person not found';
    END
END;


EXEC spProjectAssignment 'Daniel Hernandez';
EXEC spProjectAssignment 'Sandra Savage';
EXEC spProjectAssignment 'Anna Cable';