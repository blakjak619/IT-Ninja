USE tlMain;
GO

/***********************************************************************

	Author:			CMC
	BPE Owner:		Amanda Ordway/Oliver Chua
	Created date:	3/31/2015
	Description:	Rollback:
					Clears out the table tblincomingskip which holds messages 
					that cannot be extracted by Talisma due to invalid parameters.
					When this table grows too large it causes performance issues.
	CMC Case #:		INC0123549

***********************************************************************/

INSERT INTO
	dbo.tblIncomingSkip (
		tMessageUID
		,nGpAliasID
		,tSubject
	)
SELECT
	tMessageUID
	,nGpAliasID
	,tSubject
FROM
	SQLAdmin.dbo.tblIncomingSkip_back
;
GO