USE [SohuK2FrameWork]
GO
/****** Object:  StoredProcedure [dbo].[P_K2_GetMyDoc]    Script Date: 04/06/2012 15:48:20 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
Create PROCEDURE [dbo].[P_K2_GetMyDoc]
	@ActionerName nvarchar(50),
	@Folio nvarchar(300)='',
	@ProcFullName nvarchar(300)='',
	@StartTime nvarchar(50)='',
	@EndTime nvarchar(50)='',
	@PageNum int =1,
	@PageSize int =100,
	@Submitor nvarchar(50)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET @ActionerName='k2:'+@ActionerName;
	create table #TempTB(
		rowID int
		,ProcSetID int
		,ProcName nvarchar(200)
		,Folder nvarchar(200)
		,ProcFullName nvarchar(200)
		,ProcInstID int
		,Status nvarchar(50)
		,FinalAction nvarchar(100)
		,AssignedDate datetime
		,CurrentActivityName nvarchar(100)
		,ParentProcInstID int
		,Folio nvarchar(200)
		,Originator nvarchar(100)
		,StartDate datetime	
		,CallBackProcInstID ntext
		,ParentProcessName nvarchar(100)
	);
	
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
	
	Create table #TIPC (SrcProcInstID int,dstprocinstid int)
    insert #TIPC select SrcProcInstID,dstprocinstid from K2ServerLog.dbo._IPC IPC
    while @@rowcount > 0
        insert #TIPC select a.SrcProcInstID,a.dstprocinstid from K2ServerLog.dbo._IPC as a 
        inner join #TIPC as b on a.DstProcInstID = b.SrcProcInstID and a.SrcProcInstID not in(select SrcProcInstID from #TIPC);
	
	
	with MyDoc as
	(
		SELECT row_number() over( order by pinst.id DESC) as RowID
		,ps.ID AS ProcSetId
		,ps.Name AS ProcName
		,ps.Folder
		,ps.FullName
		,pinst.ID AS ProcInstID
		,s.Status		
		,ais.FinalAction
		,ais.AssignedDate  	
		,Isnull(tempActivitys.Name,'结束') as CurrentActivityName
		,IsNull(SrcProcInstID,pinst.ID) as ParentProcInstID
		FROM (SELECT * FROM K2ServerLog.dbo._ActInstSlot AS A1  WHERE  FinishDate= 
				(SELECT MAX(FinishDate) FROM K2ServerLog.dbo._ActInstSlot AS A2 WHERE A1.ProcInstID=A2.ProcInstID and a2.[user]=@ActionerName)) ais 
		INNER JOIN k2serverlog.dbo._ProcInst pinst ON ais.ProcInstID = pinst.ID --and ais.[User] <> pinst.Originator
		INNER JOIN k2serverlog.dbo._ActInst ai ON ais.ActInstID = ai.ID AND pinst.ID = ai.ProcInstID 
		INNER JOIN k2serverlog.dbo._Proc p ON pinst.ProcID = p.ID 		
		INNER JOIN k2serverlog.dbo._ProcSet ps ON p.ProcSetID = ps.ID 
		INNER JOIN k2serverlog.dbo._Status s ON pinst.Status = s.StatusID AND s.GroupName= 'Process' 
		left join #TempActivitys tempActivitys on tempActivitys.ProcInstID=pinst.ID	
		left join #TIPC on #TIPC.DstProcInstID=pinst.ID	
		WHERE ais.[User] =  @ActionerName
		AND pinst.Folio LIKE N'%' + @Folio +'%'
		AND ais.AssignedDate >= CASE @StartTime WHEN '' THEN cast( '1910-1-1 00:00:00 ' as datetime) ELSE cast( @StartTime + ' 00:00:00 ' as datetime) END
		AND ais.AssignedDate <= CASE @EndTime WHEN '' THEN getdate() ELSE cast( @EndTime + ' 23:59:59 ' as datetime) END
		and pinst.Originator like '%'+@Submitor+'%'
		--AND ps.FullName in( N'WF\Controler',N'WF\Approve')
	)
	
	insert into #TempTB
	select MyDoc.* 	
		,pinst.Folio
		,pinst.Originator
		,pinst.StartDate
		,Isnull((SELECT [Value] FROM k2serverlog.dbo._ProcInstData ProcInstData 
				WHERE ProcInstData.[ProcInstID]=MyDoc.ParentProcInstID and ProcInstData.[Name]='CallBackProcInstID'),'0') as CallBackProcInstID	
		,ps.FullName ParentProcessName
	from
		(SELECT * FROM MyDoc AS m1  WHERE  m1.ProcInstID= 
				(SELECT MAX(ProcInstID) FROM MyDoc AS m2 WHERE m1.ParentProcInstID=m2.ParentProcInstID))
		AS MyDoc
	INNER JOIN k2serverlog.dbo._ProcInst pinst ON pinst.ID = MyDoc.ParentProcInstID
	INNER JOIN k2serverlog.dbo._Proc p ON pinst.ProcID = p.ID 		
	INNER JOIN k2serverlog.dbo._ProcSet ps ON p.ProcSetID = ps.ID 
	
	select #temptb.* ,Isnull(a.Name,'结束') AS ParentActivityName
	from #temptb
	left join #TempActivitys a on a.ProcInstID=#temptb.ParentProcInstID
	where rowid between ((@pagenum-1) * @pagesize +1) and (@pagenum * @pagesize)
	order by #temptb.ProcInstID desc
	
	select ParentProcessName AS ProcessName,count(ParentProcessName) as Num from #TempTB 
    where rowid between ((@pagenum-1) * @pagesize+1) and (@pagenum * @pagesize)
	group by ParentProcessName
	
	declare @TotalNum int
	declare @PageCount int
	select @TotalNum = count(*) from #TempTB
	
	if((@Totalnum % @pagesize)>0)
		set @pagecount = (@Totalnum/@pagesize) + 1
	else
		set @pagecount = @totalnum/@pagesize

	select @Totalnum TotalNum,@PageCount PageCount
	
	drop table #TempTB
	drop table #TempActivity
	drop table #TempActivitys
	drop table #TIPC
	
    SET NOCOUNT OFF;
END






