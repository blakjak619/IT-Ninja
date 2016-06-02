USE tlMain_BPE;
GO

IF OBJECT_ID(N'dbo.usp_EMail_TruncatetblIncomingSkip', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_EMail_TruncatetblIncomingSkip;
GO

CREATE PROCEDURE dbo.usp_EMail_TruncatetblIncomingSkip
AS
BEGIN

	/***********************************************************************

		Author:			CMC
		BPE Owner:		Amanda Ordway/Oliver Chua
		Created date:	3/31/2015
		Description:	Clears out the table tblincomingskip which holds messages 
						that cannot be extracted by Talisma due to invalid parameters.
						When this table grows too large it causes performance issues.
		CMC Case #:		INC0123549

	***********************************************************************/

	IF EXISTS
		(
			SELECT 1
			FROM SQLAdmin.sys.objects
			WHERE
				name = 'tblIncomingSkip_back'
				AND type = 'u'
		)
		DROP TABLE SQLAdmin.dbo.tblIncomingSkip_back
	;

	CREATE TABLE SQLAdmin.dbo.tblIncomingSkip_back (
		tMessageUID VARCHAR(200) NULL
		,nGpAliasID INT NULL
		,tSubject VARCHAR(200) NULL
	) ON [PRIMARY];

	INSERT INTO
		SQLAdmin.dbo.tblIncomingSkip_back (
			tMessageUID
			,nGpAliasID
			,tSubject
		)
	SELECT
		tMessageUID
		,nGpAliasID
		,tSubject
	FROM
		tlMain.dbo.tblIncomingSkip
	;

	TRUNCATE TABLE tlMain.dbo.tblIncomingSkip;

END
GO

EXEC dbo.usp_EMail_TruncatetblIncomingSkip;
GO