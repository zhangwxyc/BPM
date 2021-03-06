
GO
/****** Object:  StoredProcedure [dbo].[P_K2_GetWorklist]   Script Date: 05/18/2012 10:34:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[P_K2_GetWorklist]	
	@pagenum int=1,
	@pagesize int=10,
	@ProcFullName nvarchar(100)='',
	@ActionerName nvarchar(100),
	@Folio nvarchar(300)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @P0 int;
	declare @p1 int;
	declare @Platform nvarchar(128);
	declare @Group nvarchar(max);
	set @P0=0;
	set @p1=1;
	set @Platform='ASP';	
	set @Group='0';
	
	SET @ActionerName='K2:'+@ActionerName;
	declare @strPageNum int
	declare @strPagesize int
	set @strpageNum = @pagenum
	set @strpagesize=@pagesize	
		
	DECLARE @ActionerID INT; 
	declare @P5 nvarchar(100);
	set @P5='';
	
	create table #temptb
		(
			RowID bigint
			,ProcInstID bigint
			,SN nvarchar(100)
			,Data nvarchar(300)
			,PIStartDate datetime
			,PIState tinyint
			,AIStartDate datetime
			,SlotState int
			,ProcName nvarchar(100)
			,ProcFullName nvarchar(100)
			,ActivityName nvarchar(300)
			,ProcSetID	int
			,ParentProcInstID int
			,Originator nvarchar(100)
			,Folio nvarchar(300)
			,ParentActivityName nvarchar(100)
			,ParentProcessName nvarchar(100)
			,ParentProcSetID int
		)		
	
	SELECT TOP 1 @ActionerID = ID FROM K2Server.dbo._Actioners WHERE ActionerType = 1 AND ActionerName = @ActionerName; 	

	IF (@ActionerID IS NULL) 
		BEGIN 
			INSERT INTO K2Server.dbo._Actioners(ActionerName, ActionerType) VALUES(@ActionerName, 1) 
			SET @ActionerID = CONVERT(INT, @@IDENTITY) 
		END; 
		
	create table #TempActivity(ProcInstID int,Name nvarchar(100))
	create table #TempActivitys(ProcInstID int,Name nvarchar(500))
	
	insert into #TempActivity
	SELECT  _ActInst.ProcInstID ,_Act.Name
			FROM k2serverlog.dbo._ActInst
			INNER JOIN k2serverlog.dbo._Act ON _ActInst.ActID = _Act.ID 
			inner join K2server.dbo._ProcInst pInst on pInst.id=_ActInst.procInstID 
			WHERE _ActInst.Status = 2
					
	insert into #TempActivitys
	SELECT *
	FROM
	(
		SELECT DISTINCT ProcInstID  FROM #TempActivity
	)A
	OUTER APPLY(
		SELECT [ActivityNames]= STUFF(REPLACE(REPLACE(REPLACE(
				(
					SELECT Name FROM #TempActivity where ProcInstID= A.procInstID
					FOR XML AUTO
				), '_x0023_TempActivity Name="', ''), '"/><', ';'),'"/>',''), 1, 1, '')

	)N	;	
	
		
WITH OrigActioners(ID, OriginalName, ActionerName, ActionerID, Shared) 
	AS 
		( 
			SELECT ID, ActionerName, ActionerName, ID, 0 FROM K2Server.dbo._Actioners (NOLOCK) WHERE ActionerType = 1 AND ActionerName = @ActionerName 
		) , 
WTShare(ID, WorkTypeID, Exception) 
	AS 
		(
			SELECT DISTINCT S.ID, WTS.WorkTypeID, 0 AS Exception FROM OrigActioners S 
			LEFT JOIN K2Server.dbo._WorkTypeShare WTS (NOLOCK) ON WTS.ActionerID = S.ID 
			UNION 
			SELECT DISTINCT S.ID, WES.WorkTypeExceptionID, 1 FROM OrigActioners S 
			LEFT JOIN K2Server.dbo._WorkTypeExceptionShare WES (NOLOCK) ON WES.ActionerID = S.ID 
		), 
DelegatedActioners(ActionerID,State)
		as
		(
			SELECT  WTI.ActionerID, 0 FROM WTShare S 
			JOIN k2server.dbo._WorkTypeInstance WTI (NOLOCK) ON S.Exception = 0 AND WTI.ID = S.WorkTypeID 
			UNION ALL 
			SELECT WEI.ActionerID, 0 FROM WTShare S 
			JOIN k2server.dbo._WorkTypeExceptionInstance WEI (NOLOCK) ON S.Exception = 1 AND WEI.ID = S.WorkTypeID 
			UNION ALL 
			SELECT WEI.ActionerID, 1 
			FROM WTShare S 
			JOIN k2server.dbo._WorkTypeException WTE (NOLOCK) ON S.Exception = 0 AND WTE.WorkTypeID = S.WorkTypeID 
			JOIN k2server.dbo._WorkTypeExceptionInstance WEI (NOLOCK) ON WEI.ID = WTE.ID 
		),		
WTShareActioners(ID, OriginalName, ActionerName, ActionerID, Shared) 
	AS 
		( 
			SELECT ID, OriginalName, ActionerName, ActionerID, Shared FROM OrigActioners 
			UNION 
			SELECT A.ID, A.ActionerName, A.ActionerName, A.ID AS ActionerID, 1 FROM WTShare S 
			JOIN K2Server.dbo._WorkTypeInstance WTI (NOLOCK) ON S.Exception = 0 AND WTI.ID = S.WorkTypeID 
			JOIN K2Server.dbo._Actioners A (NOLOCK) ON A.ID = WTI.ActionerID 
			UNION 
			SELECT A.ID, A.ActionerName, A.ActionerName, A.ID AS ActionerID, 1 FROM WTShare S 
			JOIN K2Server.dbo._WorkTypeExceptionInstance WEI (NOLOCK) ON S.Exception = 1 AND WEI.ID = S.WorkTypeID 
			JOIN K2Server.dbo._Actioners A (NOLOCK) ON A.ID = WEI.ActionerID 
		) ,		
Actioners(ID, OriginalName, ActionerName, ActionerID, Shared) 
	AS 
		( 
			SELECT ID, OriginalName, ActionerName, ActionerID, Shared FROM WTShareActioners 
			UNION ALL 
			SELECT ACT.id, ACT.ActionerName, CTE_ACT.ActionerName, CTE_ACT.ActionerID, CTE_ACT.Shared FROM Actioners CTE_ACT, K2Server.dbo._DestQueueUser DQU 
			INNER JOIN K2Server.dbo._DestQueue DQ (NOLOCK) ON DQ.ID = DQU.QueueID 
			INNER JOIN K2Server.dbo._Actioners ACT (NOLOCK) ON ACT.ActionerName LIKE DQ.Name 
			WHERE ACT.ActionerType = 2 AND DQU.[User] LIKE CTE_ACT.OriginalName 
		) , 
Actioner 
	AS 
		( 
			SELECT ID, OriginalName, ActionerName, ActionerID, Shared FROM Actioners 
			UNION ALL 
			SELECT ID, @ActionerName, @ActionerName, @ActionerID, 0 FROM K2Server.dbo._Actioners (NOLOCK) WHERE ActionerType = 3 AND ActionerName IN (@Group)
		),			

Worklist1
AS 
		( 	
			SELECT DISTINCT WH.ID
			, _EventAction.ID ActionID
			, WH.ProcInstID
			, WH.ActInstID
			, WH.ActInstDestID
			, WS.ID AS SlotID
			, WS.[Status] AS SlotStatus 
			,CONVERT(INT, 
				CASE WHEN (WS.[Status] < 4 AND AIR.ActionerID = A.ID AND AIR.[Execute] = 0) 
						THEN 7 
					WHEN (WS.[Status] = 0 AND A.[Shared] = 1 AND WS.ActionerID = A.ActionerID) 
						THEN 6 
					WHEN (WS.[Status] <= 4 AND A.Shared = 1) 
						THEN WS.[Status] + 5 
					WHEN ((WS.[Status] < 4 OR (WH.AISlots > 0 AND WH.AISlots = WH.Instances)) AND (WS.ActionerID > 0 AND WS.ActionerID <> A.ActionerID)) 
						THEN 2 
					WHEN (WS.[Status] = 0 AND WS.ActionerID = A.ActionerID) 
						THEN 1 
					WHEN (WS.[Status] = 3 AND WS.ActionerID = 0) 
						THEN 0 
					ELSE WS.[Status] END) AS [Status]
			,CONVERT(INT, 
				CASE WHEN (WS.ActionerID = 0 OR (AIR.[Execute] = 0 AND AIR.ActInstDestID = WH.ActInstDestID) OR A.Shared = 1) 
					THEN A.ActionerID 
					ELSE WS.ActionerID END) AS ActionerID
			,AIR.ActionName
			, AIR.[Execute]
			, CONVERT(BIT, 0) AS Denied 
			FROM K2Server.dbo._WorklistHeader WH (NOLOCK)
			JOIN K2Server.dbo._WorklistSlot WS (NOLOCK) ON WS.HeaderID = WH.ID AND WS.ProcInstID = WH.ProcInstID 
			LEFT JOIN K2Server.dbo._ActionActInstRights AIR (NOLOCK) ON AIR.ProcInstID = WH.ProcInstID AND AIR.ActInstID = WH.ActInstID 
			JOIN K2Server.dbo._EventAction (NOLOCK) ON _EventAction.EventID = AIR.EventID AND _EventAction.Name = AIR.ActionName 
			JOIN Actioner A (NOLOCK) ON A.ID = AIR.ActionerID  
			WHERE 
			(
				(
					WS.[Status]  = 0 
					AND (WH.AISlots = 0 AND WH.Instances  = 0) 
					AND (A.Shared = 0) 
					AND (AIR.ActInstDestID = WH.ActInstDestID)	
				) 
				OR 	
				(	
					WS.[Status] IN (1,3) 
					AND (WH.AISlots = 0 AND WH.Instances >= 1) 
					AND (A.Shared = 0) 
					AND (AIR.ActInstDestID = WH.ActInstDestID)
				) 
				OR 	
				(	
					WS.[Status] IN (1,3) 
					AND (WH.AISlots = 0) 
					AND (A.Shared = 1) 
					AND 
					(	
						WS.ActionerID > 0 
						AND WS.ActionerID  = A.ActionerID
					) 
					AND 
					(AIR.ActInstDestID = WH.ActInstDestID)
				) 	
				OR 	
				(
					WS.[Status]  = 0 
					AND (WH.AISlots = 0) 
					AND (A.Shared = 1) 
					AND (AIR.ActInstDestID = WH.ActInstDestID)
				) 	
				OR 	
				(
					WS.[Status]  = 4 
					AND (WH.AISlots > 0 AND WH.AISlots >= WH.Instances) 
					AND (A.Shared = 0) 
					AND (WS.ActionerID > 0 AND WS.ActionerID  = A.ActionerID AND AIR.ActInstDestID != WH.ActInstDestID)
				) 
				OR 	
				(
					WS.[Status] IN (1,3,4) 
					AND (WH.AISlots > 0 AND WH.AISlots >= WH.Instances) 
					AND (A.Shared = 0) 
					AND (WS.ActionerID > 0 AND WS.ActionerID  = A.ActionerID AND AIR.ActInstDestID  = WH.ActInstDestID)
				) 	
				OR 	
				(	
					WS.[Status] IN (1,3)   
					AND (WH.AISlots > 0 AND WH.AISlots >= WH.Instances) 
					AND (A.Shared = 0) 
					AND (WS.ActionerID > 0 AND WS.ActionerID != A.ActionerID)
				) 
				OR 
				(
					WS.[Status]  = 0       
					AND (WH.AISlots > 0 AND WH.AISlots >  WH.Instances) 
					AND (A.Shared = 0) 
					AND (WS.ActionerID >= 0) 
					AND (AIR.ActInstDestID = WH.ActInstDestID)	
				) 
				OR 	
				(
					WS.[Status] IN (1,3,4) 
					AND (WH.AISlots > 0 AND WH.AISlots >= WH.Instances) 
					AND (A.Shared = 1) 
					AND (WS.ActionerID > 0 AND WS.ActionerID  = A.ActionerID) 
					AND (AIR.ActInstDestID = WH.ActInstDestID)	
				) 	
				OR 	
				(
					WS.[Status]  = 0 
					AND (WH.AISlots > 0 AND WH.AISlots >  WH.Instances) 
					AND (A.Shared = 1) 
					AND (A.ActionerID != @ActionerID) 
					AND (AIR.ActInstDestID = WH.ActInstDestID)
				)	
			) 
			AND 
			(
				WH.[Platform] = @Platform
			) 
			AND 
			(
				(
					--( A.ActionerID in (select @p5 + ',' +cast(actionerid as nvarchar(10))  from DelegatedActioners))
					( A.ActionerID in (select actionerid  from DelegatedActioners))
					OR 
					( A.ActionerID = @ActionerID)
				) 
				AND (1 = 1)	
			) 
			UNION 
			SELECT DISTINCT WH.ID
			, _EventAction.ID ActionID
			, WH.ProcInstID
			, WH.ActInstID
			, WH.ActInstDestID
			, WS.ID AS SlotID
			, WS.[Status] AS SlotStatus
			, CONVERT(INT, 
						CASE WHEN (WS.[Status] < 4 AND AIR.ActionerID = A.ID AND AIR.[Execute] = 0) 
						THEN 7 
						WHEN (WS.[Status] = 0 AND A.[Shared] = 1 AND WS.ActionerID = A.ActionerID) 
						THEN 6 
						WHEN (WS.[Status] <= 4 AND A.Shared = 1) 
						THEN WS.[Status] + 5 
						WHEN ((WS.[Status] < 4 OR (WH.AISlots > 0 AND WH.AISlots = WH.Instances)) AND (WS.ActionerID > 0 AND WS.ActionerID <> A.ActionerID)) 
						THEN 2 
						WHEN (WS.[Status] = 0 AND WS.ActionerID = A.ActionerID) 
						THEN 1 
						WHEN (WS.[Status] = 3 AND WS.ActionerID = 0) 
						THEN 0 
						ELSE WS.[Status] END) AS [Status]
			, CONVERT(INT, 
						CASE WHEN (WS.ActionerID = 0 OR (AIR.[Execute] = 0 AND AIR.ActInstDestID = WH.ActInstDestID) OR A.Shared = 1) 
						THEN A.ActionerID 
						ELSE WS.ActionerID END) AS ActionerID
			, AIR.ActionName
			, AIR.[Execute]
			, CONVERT(BIT, 0) AS Denied 
			FROM K2Server.dbo._WorklistHeader WH (NOLOCK)
			JOIN K2Server.dbo._WorklistSlot WS (NOLOCK) ON WS.HeaderID = WH.ID AND WS.ProcInstID = WH.ProcInstID 
			LEFT JOIN K2Server.dbo._ActionActInstRights AIR (NOLOCK) ON AIR.ProcInstID = WH.ProcInstID AND AIR.ActInstID = WH.ActInstID 
			JOIN K2Server.dbo._EventAction (NOLOCK) ON _EventAction.EventID = AIR.EventID AND _EventAction.Name = AIR.ActionName 
			JOIN Actioner A (NOLOCK) ON A.ID = WS.ActionerID AND A.ActionerID = WS.ActionerID  
			WHERE 
			(	
				(
					WS.[Status]  = 0 
					AND (WH.AISlots = 0 AND WH.Instances  = 0) 
					AND (A.Shared = 0) 
					AND (AIR.ActInstDestID = WH.ActInstDestID)
				) 
				OR 
				(
					WS.[Status] IN (1,3) 
					AND (WH.AISlots = 0 AND WH.Instances >= 1) 
					AND (A.Shared = 0) 
					AND (AIR.ActInstDestID = WH.ActInstDestID)
				) 
				OR 
				(
					WS.[Status] IN (1,3) 
					AND (WH.AISlots = 0) 
					AND (A.Shared = 1) 
					AND (WS.ActionerID > 0 AND WS.ActionerID  = A.ActionerID) 
					AND (AIR.ActInstDestID = WH.ActInstDestID)
				) 
				OR 
				(
					WS.[Status]  = 0 
					AND (WH.AISlots = 0) 
					AND (A.Shared = 1) 
					AND (AIR.ActInstDestID = WH.ActInstDestID)	
				) 
				OR 
				(
					WS.[Status]  = 4  
					AND (WH.AISlots > 0 
					AND WH.AISlots >= WH.Instances) 
					AND (A.Shared = 0) 
					AND (WS.ActionerID > 0 AND WS.ActionerID  = A.ActionerID AND AIR.ActInstDestID != WH.ActInstDestID)
				) 
				OR 
				(
					WS.[Status] IN (1,3,4) 
					AND (WH.AISlots > 0 AND WH.AISlots >= WH.Instances) 
					AND (A.Shared = 0) 
					AND (WS.ActionerID > 0 AND WS.ActionerID  = A.ActionerID AND AIR.ActInstDestID  = WH.ActInstDestID)
				) 
				OR 
				(
					WS.[Status] IN (1,3)   
					AND (WH.AISlots > 0 AND WH.AISlots >= WH.Instances) 
					AND (A.Shared = 0) 
					AND (WS.ActionerID > 0 AND WS.ActionerID != A.ActionerID)
				) 
				OR 
				(
					WS.[Status]  = 0 
					AND (WH.AISlots > 0 AND WH.AISlots >  WH.Instances) 
					AND (A.Shared = 0) 
					AND (WS.ActionerID >= 0) 
					AND (AIR.ActInstDestID = WH.ActInstDestID)
				) 
				OR 
				(
					WS.[Status] IN (1,3,4) 
					AND (WH.AISlots > 0 AND WH.AISlots >= WH.Instances) 
					AND (A.Shared = 1) 
					AND (WS.ActionerID > 0 AND WS.ActionerID  = A.ActionerID) 
					AND (AIR.ActInstDestID = WH.ActInstDestID)	
				) 
				OR 
				(
					WS.[Status]  = 0 
					AND (WH.AISlots > 0 AND WH.AISlots >  WH.Instances) 
					AND (A.Shared = 1) 
					AND (A.ActionerID != @ActionerID) 
					AND (AIR.ActInstDestID = WH.ActInstDestID)
				)
			) 
			AND (WH.[Platform] = @Platform) 
			AND
			(
				(
					--(A.ActionerID in ( select @p5 + ',' +cast(actionerid as nvarchar(10))  from DelegatedActioners))
					 ( A.ActionerID in (select actionerid  from DelegatedActioners))
					 OR (A.ActionerID = @ActionerID)
				)
				AND (1 = 1)	
			) 	
		),
		
Worklist2 
AS 
		(
			SELECT DISTINCT WH.ID, WH.ProcInstID, WH.ActInstID, WH.ActInstDestID, WS.ID AS SlotID, WS.[Status] AS SlotStatus,
			CONVERT(INT, CASE WHEN 	(WS.ActionerID = A.ActionerID AND WS.[Status] = 0) THEN 1 WHEN (WS.ActionerID = 0 AND WS.[Status] = 3) THEN 0 ELSE WS.[Status] END) AS [Status], 
			CONVERT(INT, CASE WHEN (WS.ActionerID = 0 OR AR.[Execute] = 0 OR AR.Denied = 1 OR A.Shared = 1) THEN A.ActionerID ELSE WS.ActionerID END) AS ActionerID, 
			AR.ActionName, AR.[Execute], AR.Denied 
			FROM K2Server.dbo._WorklistHeader WH (NOLOCK) 
			JOIN K2Server.dbo._WorklistSlot WS (NOLOCK) ON WS.HeaderID = WH.ID AND WS.ProcInstID = WH.ProcInstID 
			JOIN K2Server.dbo._ProcInst PI (NOLOCK) ON PI.ID = WH.ProcInstID 
			JOIN K2Server.dbo._Proc P (NOLOCK) ON P.ID = PI.ProcID 
			JOIN K2Server.dbo._ActionRights AR (NOLOCK) ON AR.ProcSetID = P.ProcSetID 
			JOIN Actioner A (NOLOCK) ON A.ID = AR.ActionerID 
			JOIN K2Server.dbo._Act ACT (NOLOCK) ON ACT.ID = WH.ActID 
			JOIN K2Server.dbo._Event E (NOLOCK) ON E.ID = WH.EventID
			WHERE
			(	
				AR.ActivityName = ACT.Name
				AND 
				AR.EventName = E.Name 
				AND 
				(AR.[Execute] = 0 OR AR.Denied = 1 OR (AR.[Execute] = 1 AND AR.Denied = 0)) 
				AND
				(WS.[Status] < 4 AND A.Shared = 0)
			) 
			AND 			
			WH.[Platform] = @Platform  
			AND 			
			(
				--A.ActionerID in (select @p5 + ',' +cast(actionerid as nvarchar(10))  from DelegatedActioners)					 
				( A.ActionerID in (select actionerid  from DelegatedActioners))
				OR
				A.ActionerID = @ActionerID
			)				 	
		)
		
SELECT WL.* INTO #WORKLIST3
FROM (	
	SELECT ActionID, ID, ProcInstID, ActInstID, ActInstDestID, SlotID, SlotStatus, [Status], ActionerID, ActionName, [Execute], Denied 	
	FROM WORKLIST1 	
	UNION 
	SELECT NULL, ID, ProcInstID, ActInstID, ActInstDestID, SlotID, SlotStatus, [Status], ActionerID, ActionName, [Execute], Denied 
	FROM WORKLIST2 
	) AS WL;
	
DELETE WL1 FROM #WORKLIST3 WL1 	
WHERE 
(	
	[Status] = 2 
	OR 
	(SlotStatus = 0 AND ([Status] = 0 OR [Status]-5 = 0))
	OR(SlotStatus = 0 AND ([Status] = 1 OR [Status]-5 = 1))
) 
AND 
	SlotID >= ( 
					SELECT MIN(WL2.SlotID) FROM #WORKLIST3 WL2 
					WHERE WL2.[Status] <> 2 AND WL2.ProcInstID = WL1.ProcInstID 
											AND WL2.ActInstDestID = WL1.ActInstDestID 
											AND 
											(	
												(	
													(WL2.SlotID <> WL1.SlotID OR WL1.[Status] = 2) 
													AND 
														(	
															(	
																(	
																	WL2.[Status] = WL2.SlotStatus 
																	OR 
																	(WL2.[Status]  = 1 AND WL2.SlotStatus = 0)
																) 
																AND 
																(WL1.[Status]   <> 1 OR WL2.SlotStatus <> 0)
															) 
															OR  
															(	
																(	
																	WL2.[Status]-5 = WL2.SlotStatus 
																	OR 
																	(WL2.[Status]-5 = 1 AND WL2.SlotStatus = 0)
																)
																AND 
																(WL1.[Status]-5 <> 1 OR WL2.SlotStatus <> 0)
															)
															OR
															(WL2.[Status] = 7)
														)
												)
												AND 
												(	
													(WL1.[Status] < 5 AND WL2.ActionerID = @ActionerID) 
													OR 
													WL2.ActionerID = WL1.ActionerID
												) 
												OR 
												(WL2.[Status] IN (4,7) AND WL2.ActionerID = WL1.ActionerID)
											)
			  ); 
DELETE WL1 FROM #WORKLIST3 WL1 
WHERE 
	(	
		[Status] IN (2,4)
		OR 
		([Status]-5 = 4) 
		OR 
		(	
			SlotStatus = 0 
			AND 
			(	
				[Status] = 0 
				OR [Status]-5 = 0
			)
		) 
		OR 
		(	
			SlotStatus = 0 
			AND 
			(	
				[Status] = 1 
				OR 
				[Status]-5 = 1
			)
		)
	) 
	AND 
		SlotID <= 
			(	
				SELECT MIN(WL2.SlotID) FROM #WORKLIST3 WL2 
				WHERE WL2.[Status] <> 2 
					  AND WL2.ProcInstID = WL1.ProcInstID 
					  AND WL2.ActInstDestID = WL1.ActInstDestID 
					  AND 
					  (	
						(	
							(WL2.SlotID <> WL1.SlotID OR WL1.[Status] = 2) 
							AND 
							(	
								WL2.[Status] IN (0,1,3,4) 
								OR 
								(WL2.[Status] = 7) 
								OR 
								WL2.[Status]-5 IN (0,1,3,4)
							)
						) 
						AND 
						(	
							(WL1.[Status] < 5 AND WL2.ActionerID = @ActionerID) 
							OR WL2.ActionerID = WL1.ActionerID
						)
						OR  
						(	
							WL2.[Status] IN (4,7) AND WL2.ActionerID = WL1.ActionerID
						)
					)
				); 
DELETE [WL1] FROM #WORKLIST3 [WL1] 
WHERE 
	([Status] IN (1,2) OR [Status]-5 = 1) 
	AND   
	SlotID > 
		(	
			SELECT MIN(WL2.SlotID) FROM #WORKLIST3 WL2 
			WHERE WL2.[Status] IN (1,2,6) AND WL2.ProcInstID = WL1.ProcInstID AND 
			WL2.ActInstDestID = WL1.ActInstDestID AND WL2.ActionerID = WL1.ActionerID
		); 
		
WITH #WORKLIST 
AS 
( 
	SELECT WL3.ID HeaderID, 
		WL3.SlotID,
		 CASE WHEN (WL3.[Status] = 2) THEN WL3.[Status] ELSE WL3.SlotStatus END AS HeaderStatus, 
		 A.ActionerName, 
		 PI.*, 
		 DENSE_RANK() OVER (ORDER BY WL3.ProcInstID, WL3.ActInstDestID) AS RowNumber, 
		 ActionName, 
		 [Execute], 
		 Denied, 
		 WL3.ActionID 
	FROM #WORKLIST3 WL3 
	JOIN K2Server.dbo._Actioners A (NOLOCK) ON A.ID = WL3.ActionerID 
	JOIN K2Server.dbo._ProcInst PI (NOLOCK) ON PI.ID = WL3.ProcInstID AND PI.[Status] NOT IN (0,4)   --4:Stop 0:Error
	WHERE 
	(
		( 
			(WL3.[Status] <> 2 AND WL3.SlotStatus = @P0) --0:Available 1:Open 3:Sleep
			OR 
			(WL3.[Status] <> 2 AND WL3.SlotStatus = @P1)
			OR 
			(WL3.[Status] <> 2 AND WL3.SlotStatus = 3)
		) 
	) 
	AND 
	(WL3.SlotStatus != 4 AND WL3.[Status] != 7)
),		
MyTask	
as	
	(	
		SELECT distinct 
		WL.headerid, 
		WL.SlotID, 
		WL.ActionerName,
		WL.ExecutingProcID, 
		WL.[Status] ProcInstStatus, 
		WL.HeaderStatus SlotStatus,
		WL.StartDate,  
		WL.Folio, 
		WL.ID ProcInstID, 
		WH.EventID, 
		WH.Data, 
		WH.ActInstDestID, 
		WH.ActID, 
		WH.ActInstID,
		WH.AIStartDate, 
		WH.EIStartDate
		,_procset.[name] as ProcName
		,_procset.FullName
		,_procset.id as ProcSetID
		,act1.Name as ActivityName
		,cast((SELECT Convert(nvarchar(100),[Value]) FROM k2serverlog.dbo._ProcInstData ProcInstData 
			WHERE ProcInstData.[ProcInstID]=WH.ProcInstID and ProcInstData.[Name]='ParentProcInstID') as int) as ParentProcInstID		
		FROM #WORKLIST WL 
		JOIN K2Server.dbo._WorklistHeader WH ON WH.ID = WL.HeaderID AND WH.ProcInstID = WL.ID 
		JOIN K2Server.dbo._WorklistSlot AS WS ON WS.ID = WL.SlotID AND WS.HeaderID = WH.ID 
		inner join K2Server.dbo._procinst on _procinst.id=WL.ID
		inner join K2Server.dbo._proc on _proc.id=_procinst.procid 
		inner join K2Server.dbo._procset on _procset.id=_proc.procsetid
		left join #TempActivitys act1 on act1.ProcInstID=WL.ID
		WHERE WL.[execute]=1 AND WL.folio like '%'+@Folio + '%' 
	)
	
insert into #temptb
	Select 
	row_number() over (order by  T.AIStartDate desc) as RowID
	,T.ProcInstID	
	,cast(T.ProcinstID as nvarchar(10)) + '_' + cast(T.ActInstDestID as nvarchar(10)) SN
	,T.Data
	,T.StartDate ProcStartDate
	,T.ProcInstStatus ProcState
	,T.AIStartDate ActivityStartDate
	,T.SlotStatus SlotState
	,T.ProcName
	,T.FullName
	,T.ActivityName
	,T.ProcSetID
	,t.ParentProcInstID
	,ParentProcInst.Originator
	,ParentProcInst.Folio
	,act2.Name ParentActivityName
	,_procset.FullName ParentProcessName
	,_procset.ID ParentProcSetID
	from MyTask T 
	left join K2Server.dbo._procinst ParentProcInst on ParentProcInst.id=T.ParentProcInstID 
	left join K2Server.dbo._proc on _proc.id=ParentProcInst.procid 
	left join K2Server.dbo._procset on _procset.id=_proc.procsetid	
	left join #TempActivitys act2 on act2.ProcInstID=T.ParentProcInstID 	
	
	
	select * from #temptb
	where rowid between ((@strpagenum-1) * @strpagesize +1) and (@strpagenum * @strpagesize)
		
	select ParentProcessName AS ProcessName,count(ParentProcessName) as Num from #temptb 
	where rowid between ((@strpagenum -1) * @strpagesize +1) and (@strpagenum * @strpagesize)
	group by ParentProcessName
		
	declare @TotalNum int
	declare @PageCount int
	select @TotalNum = count(*) from #TempTB

	if((@Totalnum % @strpagesize)>0)
		set @pagecount = (@Totalnum/@strpagesize) + 1
	else
		set @pagecount = @totalnum/@strpagesize

	select @Totalnum TotalNum,@PageCount PageCount

	drop table #temptb
	drop table #TempActivity
	drop table #TempActivitys
	SET NOCOUNT OFF;
END



