/* Custom All Work */
DECLARE @SHOWACTIVITIES char = '1' --''{{SHOWACTIVITIES}}''
DECLARE @SHOWINACTIVE char = '1' --''{{SHOWINACTIVE}}''

Select WorkItemId as [Id], 
	WorkItem.Title, 
	DisplayStringStatus.DisplayString as [Status], 
	IIF(WorkItem.ClassId = 'bfd90aaa-80dd-0fbb-6eaf-65d92c1d8e36', ReviewerCIUser.DisplayName, WorkItem.AssignedUser) as AssignedUser,
	WorkItem.AffectedUser, 
	AffectedCIUser.Office,
	DisplayStringTierId.DisplayString as SupportGroup,
	DisplayStringWorkItemCategory.DisplayString as Category,
	WorkItem.LastModified AT TIME ZONE 'UTC' as LastModified, --AT TIME ZONE requires SQL2016. Allows kendo grids to correctly convert dates to the browser's local time.
	WorkItem.Created AT TIME ZONE 'UTC' as Created --AT TIME ZONE requires SQL2016. Allows kendo grids to correctly convert dates to the browser's local time.
from ServiceManagement.dbo.WorkItem
inner join ServiceManagement.dbo.DisplayString as DisplayStringStatus on DisplayStringStatus.ElementID = WorkItem.StatusId
	and DisplayStringStatus.LocaleID = 'ENU'
	and (@SHOWINACTIVE != '1' and DisplayStringStatus.DisplayString not in ('Resolved', 'Closed', 'Completed', 'Failed', 'Skipped', 'Cancelled')
		or (@SHOWINACTIVE = '1' and DisplayStringStatus.DisplayString is not null)
	)
left join ServiceManagement.dbo.DisplayString as DisplayStringTierId on DisplayStringTierId.ElementID = WorkItem.TierId
	and DisplayStringTierId.LocaleID = 'ENU'

left join ServiceManagement.dbo.DisplayString as DisplayStringWorkItemCategory 
	on DisplayStringWorkItemCategory.ElementID = WorkItem.CategoryId
	and DisplayStringWorkItemCategory.LocaleId = 'ENU'

outer apply (
	select top 1 * from ServiceManagement.dbo.WorkItem$Review as ReviewObjects
	where ReviewObjects.ReviewActivityId = WorkItem.Id 
		and ReviewObjects.ReviewerId is not null
	order by ReviewObjects.ReviewId Desc --newer reviewers are more likely to have a person, instead of the OOB blank entry.
) as ReviewObjects

left join ServiceManagement.dbo.CI$User as AffectedCIUser on AffectedCIUser.Id = WorkItem.AffectedUserId
left join ServiceManagement.dbo.CI$User as ReviewerCIUser on ReviewerCIUser.ID = ReviewObjects.ReviewerId

where (
	(	WorkItem.ClassId not in ('7AC62BD4-8FCE-A150-3B40-16A39A61383D', 'BFD90AAA-80DD-0FBB-6EAF-65D92C1D8E36')
		AND @SHOWACTIVITIES != '1' 
	)
	OR ( @SHOWACTIVITIES = '1')
)

order by LastModified Desc

--end