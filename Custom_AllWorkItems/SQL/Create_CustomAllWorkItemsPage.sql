--use a GUID generator to create some new guids for your view panel and navigation node.  NOTE: All guids must be completely lower case. Powershell syntax [GUID]::NewGuid()
DECLARE @NavNodeGuid nvarchar(255)                  = 'a8045e60-8db2-4f14-80f5-93bb4da011e9' 
DECLARE @ViewPanelGuid nvarchar(255)                = '30a1d6a1-a1d6-4e77-be96-5239fa0def05'
DECLARE @DataSourceGuid nvarchar(255) 				= 'dd46924d-9199-4b5d-ae35-ea275a539df4'

-- set the page title and the default language
DECLARE @MenuTitle nvarchar(255)  		= 'Custom All Work'
DECLARE @PageTitle nvarchar(255)		= 'Custom All Work Items Page'
DECLARE @Locale nvarchar(3)				= 'ENU'
DECLARE @DivId nvarchar(255)			= 'customMainGrid'
DECLARE @ScriptLocation nvarchar(255)	= '/CustomSpace/Custom_AllWorkItems.js'

--this just deletes it if it already exists so that you can iteratively tweak it and recreate it easily
delete FROM DisplayString where ElementID = @NavNodeGuid and LocaleID = @Locale
delete FROM NavigationNode where Id = @NavNodeGuid
delete FROM ViewPanel where id = @ViewPanelGuid
delete FROM DataSource where Id = @DataSourceGuid


--this creates the navigation node display string
INSERT INTO [dbo].[DisplayString]  (ElementID, LocaleID, DisplayString) 
VALUES (@NavNodeGuid, @Locale, @MenuTitle)

--Create the navigation node. This example creates a navigation node with only one row/one column with a single view panel
INSERT INTO NavigationNode(Id, [Definition], Ordinal, Sealed, IsPublic, IsVisible, LicenseRequired, IconClass)
VALUES (
@NavNodeGuid, 
'{"Id":"' + @NavNodeGuid + '","layoutType":"full","view":{"header":{"title":"' + @MenuTitle + '","subTitle":"' + @PageTitle + '"},"body":{"content":{"rows":[{"columns":[{"ColSpan":12,"type":"viewPanel","ViewPanelId":"' + @ViewPanelGuid + '"}]}]}}}}',
0,1,0,0,NULL, 'fa fa-paint-brush')

--Create the view panel
--This example defines a type=HTML view panel that fills up the entire view panel port and embeds an iframe pointed at the URL specified.  
--You can include HTML using an iframe like this example or you can hard code any HTML/Javascript in the view panel content attribute.
INSERT INTO ViewPanel(Id, [Definition], TypeId)
VALUES (
@ViewPanelGuid,
'{
"id":"' + @ViewPanelGuid + '",
"type":"html",
"content":"
<div>
<head>
	<title>' + @PageTitle + '</title>
	<!--<link rel=\"stylesheet\" type=\"text/css\" href=\"/CustomSpace/supercustom.css\">-->
	<script src=\"' + @ScriptLocation + '\"></script>
	<style>
		#' + @DivId + ' tr:hover { background-color: lightcyan; color: black; }
		#' + @DivId + ' tr:hover td:nth-of-type(-n+2) { background-color: skyblue; }
		#' + @DivId + ' th:hover, #customMainGrid td:nth-of-type(-n+2):hover  { cursor: pointer; }
	</style>
</head>

<div id=\"' + @DivId + '\" customdashid=' + @DataSourceGuid + ' >
	Loading file \"' + @ScriptLocation + '\"...?
</div>
"}',
'html'
)

--Create the datasource query.
DECLARE @Query nvarchar(max) = '
/* Custom All Work */
DECLARE @SHOWACTIVITIES char = ''{{SHOWACTIVITIES}}''
DECLARE @SHOWINACTIVE char = ''{{SHOWINACTIVE}}''

Select WorkItemId as [Id], 
	WorkItem.Title, 
	DisplayStringStatus.DisplayString as [Status], 
	IIF(WorkItem.ClassId = ''bfd90aaa-80dd-0fbb-6eaf-65d92c1d8e36'', ReviewerCIUser.DisplayName, WorkItem.AssignedUser) as AssignedUser,
	WorkItem.AffectedUser, 
	AffectedCIUser.Office,
	DisplayStringTierId.DisplayString as SupportGroup,
	DisplayStringWorkItemCategory.DisplayString as Category,
	WorkItem.LastModified AT TIME ZONE ''UTC'' as LastModified, --AT TIME ZONE requires SQL2016. Allows kendo grids to correctly convert dates to the browsers local time.
	WorkItem.Created AT TIME ZONE ''UTC'' as Created --AT TIME ZONE requires SQL2016. Allows kendo grids to correctly convert dates to the browsers local time.
from ServiceManagement.dbo.WorkItem
inner join ServiceManagement.dbo.DisplayString as DisplayStringStatus on DisplayStringStatus.ElementID = WorkItem.StatusId
	and DisplayStringStatus.LocaleID = ''ENU''
	and (@SHOWINACTIVE != ''1'' and DisplayStringStatus.DisplayString not in (''Resolved'', ''Closed'', ''Completed'', ''Failed'', ''Skipped'', ''Cancelled'')
		or (@SHOWINACTIVE = ''1'' and DisplayStringStatus.DisplayString is not null)
	)
left join ServiceManagement.dbo.DisplayString as DisplayStringTierId on DisplayStringTierId.ElementID = WorkItem.TierId
	and DisplayStringTierId.LocaleID = ''ENU''

left join ServiceManagement.dbo.DisplayString as DisplayStringWorkItemCategory 
	on DisplayStringWorkItemCategory.ElementID = WorkItem.CategoryId
	and DisplayStringWorkItemCategory.LocaleId = ''ENU''

outer apply (
	select top 1 * from ServiceManagement.dbo.WorkItem$Review as ReviewObjects
	where ReviewObjects.ReviewActivityId = WorkItem.Id 
		and ReviewObjects.ReviewerId is not null
	order by ReviewObjects.ReviewId Desc --newer reviewers are more likely to have a person, instead of the OOB blank entry.
) as ReviewObjects
--left join ServiceManagement.dbo.WorkItem$Review as ReviewObjects on ReviewObjects.ReviewActivityId = WorkItem.Id
left join ServiceManagement.dbo.CI$User as AffectedCIUser on AffectedCIUser.Id = WorkItem.AffectedUserId
left join ServiceManagement.dbo.CI$User as ReviewerCIUser on ReviewerCIUser.ID = ReviewObjects.ReviewerId

where (
	(	WorkItem.ClassId not in (''7AC62BD4-8FCE-A150-3B40-16A39A61383D'', ''BFD90AAA-80DD-0FBB-6EAF-65D92C1D8E36'')
		AND @SHOWACTIVITIES != ''1'' 
	)
	OR ( @SHOWACTIVITIES = ''1'')
)

order by LastModified Desc
'
INSERT INTO [dbo].[DataSource] (Id, Title, ConnectionString, Query)
VALUES (@DataSourceGuid, 'Dashbaord - ' + @MenuTitle, NULL, @Query)


--end

