/*****************************************************
Title: Using R in SQL Server Reporting Services (SSRS)
Author: Tomaz Kastrun
Blog: http://tomaztsql.wordpress.com
Date: 03.03.2018
*****************************************************/


USE [master];
GO


CREATE DATABASE R_SSRS;
GO

USE R_SSRS;
GO

-- ----------------
-- Create some data
-- ----------------

DROP TABLE IF EXISTS R_data;
GO

CREATE TABLE R_data
(
 v1  INT
,v2  INT
,v_low INT
,v_high INT
,letter CHAR(1)
);
GO

CREATE OR ALTER PROCEDURE generate_data
AS
BEGIN
	INSERT INTO R_data(v1,v2,v_low,v_high,letter)
	SELECT TOP 10
		 CAST(v1.number*RAND() AS INT) AS v1
		,CAST(v2.number*RAND() AS INT) AS v2
		,v1.low AS v_low
		,v1.high AS v_high
		,SUBSTRING(CONVERT(varchar(40), NEWID()),0,2) AS letter-- uniqueidentifier
	FROM master..spt_values AS v1
	CROSS JOIN master..spt_values AS v2
	WHERE
		v1.[type] = 'P'
	AND v2.[type] = 'P'
	ORDER BY NEWID() ASC;
END
GO

EXEC generate_data;
GO 10


SELECT count(*), letter FROM R_data GROUP by letter


-- ----------------------------
-- Pseudo parametrization
-- ----------------------------

--Example
SELECT * FROM R_data
WHERE 
	v1 > 200
AND letter IN ('1','2','3')

-- START: parametrized example; Pseudo example
DECLARE @v1 INT = 400
DECLARE @letters VARCHAR(100) = '1,2,3'

SELECT * FROM R_data
WHERE 
	v1 > @v1
AND letter IN (@letters)
--- END

-- ----------------------------
-- Create R Procedure
-- for single and
-- multiple valued parameters
-- ----------------------------

CREATE OR ALTER PROCEDURE sp_R1
(
	 @v1 INT
	,@lett VARCHAR(20)
)
AS
BEGIN

DECLARE @myQuery NVARCHAR(1000)

CREATE TABLE #t (let CHAR(1))
INSERT INTO #t
SELECT value
FROM STRING_SPLIT(@lett,',')


SET @myQuery = N'
		SELECT * FROM R_data
		WHERE 
			v1 > '+CAST(@v1 AS VARCHAR(10))+'
		AND letter IN (SELECT * FROM #t)'

EXEC sp_execute_external_script
	 @language = N'R'
	,@script = N'
		df	<- InputDataSet 
		df_res <- summary(df)
		df_res <- data.frame(df_res)
		OutputDataSet <- df_res'
	,@input_data_1 = @myQuery
WITH RESULT SETS
((
   v1 NVARCHAR(100)
  ,v2 NVARCHAR(100)
  ,freq NVARCHAR(100)
))
END;
GO


-- Test the procedure!
EXEC sp_R1 
	 @v1 = 200
	,@lett = '1,2,3';
GO


-- Reporting 
-- DS_parameter_V1 
SELECT 
	v1
FROM R_data
GROUP BY v1
ORDER By V1

--Reporting 
--DS_parameter_lett
SELECT
	letter 
FROM r_data
GROUP BY letter
ORDER BY letter

-- ----------------------------
-- Create R Procedure
-- for generating R graph
-- ----------------------------


CREATE OR ALTER PROCEDURE sp_R2
(
	 @lett VARCHAR(20)
)
AS
BEGIN

DECLARE @myQuery NVARCHAR(1000)


CREATE TABLE #t (let CHAR(1))
INSERT INTO #t
SELECT value
FROM STRING_SPLIT(@lett,',')


SET @myQuery = N'
		SELECT v1,letter FROM R_data
		WHERE 
			letter IN (SELECT * FROM #t)'

EXEC sp_execute_external_script
	 @language = N'R'
	,@script = N'
		df	<- InputDataSet 
		image_file <- tempfile()
		jpeg(filename = image_file, width = 400, height = 400)
		boxplot(df$v1~df$letter)
		dev.off()
        OutputDataSet <- data.frame(data=readBin(file(image_file, "rb"), what=raw(), n=1e6))'
	,@input_data_1 = @myQuery
WITH RESULT SETS
((
   boxplot VARBINARY(MAX)
))
END;
GO

-- test
EXEC sp_R2 @lett = '1,2,3';
GO

--Reporting 
--DS_parameter_lett
SELECT
	letter 
FROM r_data
GROUP BY letter
ORDER BY letter



-- CLEAN UP
USE [master];
GO

ALTER DATABASE R_SSRS SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

DROP DATABASE IF EXISTS R_SSRS;
GO