--use a GUID generator to create some new guids for your view panel and navigation node.  NOTE: All guids must be completely lower case. Powershell syntax [GUID]::NewGuid()
DECLARE @NavNodeGuid nvarchar(255)                  = 'b2377df9-b233-44d8-a363-05a60ce2dd03' 
DECLARE @ViewPanelGuid nvarchar(255)                = '874d3a48-0ebf-4355-b8a9-1f32e57ef3b9'
DECLARE @DataSourceGuid nvarchar(255) 				= 'ce5c42fa-b4e9-43ff-ac2f-9c0b11fc8fb2'

-- set the page title and the default language
DECLARE @MenuTitle nvarchar(255)  		= 'Team Work Items (Custom)'
DECLARE @PageTitle nvarchar(255)		= 'Team Work Items Page (Custom)'
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
	WorkItem.Created AT TIME ZONE ''UTC'' as Created, --AT TIME ZONE requires SQL2016. Allows kendo grids to correctly convert dates to the browsers local time.

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

left join ServiceManagement.dbo.CI$User as AffectedCIUser on AffectedCIUser.Id = WorkItem.AffectedUserId
left join ServiceManagement.dbo.CI$User as ReviewerCIUser on ReviewerCIUser.ID = ReviewObjects.ReviewerId

--Get CRs custom support group.
left join ServiceManager.dbo.MTV_System$WorkItem$ChangeRequest as ChangeRequest 
	on ChangeRequest.BaseManagedEntityId = WorkItem.Id
left join ServiceManagement.dbo.DisplayString as DisplayStringCRSupportGroup on DisplayStringCRSupportGroup.ElementID = ChangeRequest.SupportGroup_4A79F4D2_652F_0653_5604_98E1B732ECDD
	and DisplayStringCRSupportGroup.LocaleID = ''ENU''

where (
	( 
		(	WorkItem.ClassId not in (''7AC62BD4-8FCE-A150-3B40-16A39A61383D'', ''BFD90AAA-80DD-0FBB-6EAF-65D92C1D8E36'')
			AND @SHOWACTIVITIES != ''1''	
		)
		OR ( @SHOWACTIVITIES = ''1'')
	)
	AND (
		WorkItem.AssignedUserId = @UserId --@UserId is a special Cireson token for the logged-in user GUID.
		or ReviewObjects.ReviewerId = @UserId
		or WorkItem.TierId in (
			select SupportGroupMapping.EnumerationId from GroupMembership_CI$DomainGroup_CI$User as GroupMembership
				inner join CI$DomainGroup as DomainGroup on DomainGroup.Id = GroupMembership.DomainGroupId
					and GroupMembership.UserId = @UserId
				inner join SupportGroupMapping_CI$DomainGroup_Enumeration as SupportGroupMapping on SupportGroupMapping.DomainGroupId = DomainGroup.Id
		)
		or ChangeRequest.SupportGroup_4A79F4D2_652F_0653_5604_98E1B732ECDD in (
			select SupportGroupMapping.EnumerationId from GroupMembership_CI$DomainGroup_CI$User as GroupMembership
				inner join CI$DomainGroup as DomainGroup on DomainGroup.Id = GroupMembership.DomainGroupId
					and GroupMembership.UserId = @UserId
				inner join SupportGroupMapping_CI$DomainGroup_Enumeration as SupportGroupMapping on SupportGroupMapping.DomainGroupId = DomainGroup.Id
		)
	)
)
	
order by WorkItem.LastModified Desc
'
INSERT INTO [dbo].[DataSource] (Id, Title, ConnectionString, Query)
VALUES (@DataSourceGuid, 'Dashboard - ' + @MenuTitle, NULL, @Query)


--end

