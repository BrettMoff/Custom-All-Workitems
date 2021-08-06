// v2018.12.20_1
// Created by: Joivan
var mainDataSourceGuid = null;
var strMainGridDiv = "customMainGrid"; //The main and only div that this page starts with.

fn_AddCustomDashboardToPage();

function fn_AddCustomDashboardToPage() {
	
	//Get our dashboard ID from our main (and only) div with ID "customMainGrid"
	var mainDivElement = $("#" + strMainGridDiv);
	if (mainDivElement.length == 0) {
		alert("Found 0 elements with ID '" + strMainGridDiv + "'.");
		return;
	}
	
	mainDivElement.empty();
	mainDataSourceGuid = mainDivElement.attr("customdashid");
	if (mainDivElement.length == 0) {
		alert("The div element with ID '" + strMainGridDiv + "' does not contain a value for the dashboard ID, with name 'customdashid'.");
		return;
	}
	
	//First, get our query string parameters, which includes our custom dashboard parameters.
	var showActivitiesParam = getUrlParam("SHOWACTIVITIES");
	if (showActivitiesParam == null) {
		showActivitiesParam = "1"; //Set a default value because if null, we want this to be true.
	}
	
	var showInactiveParam = getUrlParam("SHOWINACTIVE");
	
	
	//Do our API call potentially with two params. SHOWACTIVITIES and SHOWINACTIVE
	//http://scsm02/api/v3/Dashboard/GetDashboardDataById/?dateFilterType=NoFilter&priorityId=3&queryId=b6aac3c1-d278-a21e-49c5-bbf0303b90d9
	$.ajax({
		url: "/api/v3/Dashboard/GetDashboardDataById/?dateFilterType=NoFilter" + "&queryId=" + mainDataSourceGuid + 
				"&SHOWACTIVITIES=" + showActivitiesParam + 
				"&SHOWINACTIVE=" + showInactiveParam
				,
		type: "GET",
		async: false,
		success: function (data) {
			CreateAndUpdateAllWorkKendoGridWithData(data) 
		}
	});
}

function CreateAndUpdateAllWorkKendoGridWithData(dashData) {
	
	if (dashData.length == 0) {
		$("#" + strMainGridDiv).empty();
		$("#" + strMainGridDiv).append("<div>Returned zero results when querying data source with ID '" + mainDataSourceGuid + "'. Was this datasource added to ServiceManagement?");
		return;
	}
	
	//console.log("AllWorkContent");
	//console.log(dashData);
	
	var strShowActivities = "";
	if (getUrlParam("SHOWACTIVITIES") != "0") {
		strShowActivities = " checked";
	}
	
	var strShowInactive = "";
	if (getUrlParam("SHOWINACTIVE") == "1") {
		strShowInactive = " checked";
	}
	
	//Make the kendo grid. Lots of options exist. //	http://docs.telerik.com/kendo-ui/api/javascript/ui/grid
	
	var strHtmlTemplate = '<a id=exportToExcel class="k-button k-button-icontext k-grid-excel pull-right btn-grid-export" href="&num;">' + 
							'<span class="k-icon k-i-excel"></span>Export to Excel' + 
					      '</a>' + 
						  '<a id=resetView class="k-button k-button-icontext btn-clear-grid-filters pull-right" href="&num;">' + 
							'Reset View' + 
					      '</a>' + 
						  '<label class="checkbox checkbox-primary" id="lblToggleActivities">' + 
							'<input class="k-checkbox" type="checkbox" data-checked="false" id="cbxShowActivitiesInGrid" ' + strShowActivities + '>' + 
							'<span class="checkbox-label">Show Activities</span>' + 
						  '</label>' +
						  '<label class="checkbox checkbox-primary" id="lblToggleInactiveWorkItems">' + 
							'<input class="k-checkbox" type="checkbox" data-checked="false" id="cbxShowInactiveWorkItems" ' + strShowInactive + '>' + 
							'<span class="checkbox-label">Show Inactive Work Items</span>' + 
						  '</label>';
						  
	//Set up the columns, based on the datasource's data. Make the first two columns bigger.  || columns: [ { field: "name", width: "200px" }, { field: "age" } ]
	
	var arrColumns = [];
	var firstDashData = dashData[0];
	var columnNames = Object.getOwnPropertyNames(firstDashData);
	
	for(var i=0; i < columnNames.length; i++) {
		
		if (columnNames[i].indexOf("_") == 0) {
			continue;
		}
		if (columnNames[i] == "uid" || columnNames[i] == "parent") {
			break
		}
		
		strThisFieldNameLower = columnNames[i].toLowerCase();
		
		if (arrColumns.length == 0) {
			arrColumns.push( { field: columnNames[i], width: "90px" });
		}
		else if (arrColumns.length == 1) {
			arrColumns.push( { field: columnNames[i], width: "25%" });
		}
		else{
			//If this is a date field, then assign a template for it. 
			if (strThisFieldNameLower == "created" || strThisFieldNameLower == "lastmodified" || strThisFieldNameLower.indexOf("date") > -1) {
				arrColumns.push( { field: columnNames[i], template: '#= kendo.toString(kendo.parseDate(' + columnNames[i] + '), "dd MMM yyyy hh:mm:ss")#' });
			}
			else{
				arrColumns.push( { field: columnNames[i]});
			}
		}
	}
	
	//Create our schema, containing a model and fields. || var objSchema = { model: { fields: { WorkItemId:{type:"string"}, Created:{type:"date"} } } };
	var objSchemaModelFields = {};
	for(var i=0; i < arrColumns.length; i++) {
		var strThisFieldName = arrColumns[i].field;
		var strThisFieldNameLower = strThisFieldName.toLowerCase();
		if (strThisFieldNameLower == "created" || strThisFieldNameLower == "lastmodified" || strThisFieldNameLower.indexOf("date") > -1) {
			objSchemaModelFields[strThisFieldName] = {type:"date"};
		}
		
	}
	
	var objSchema = {
		model: {
			fields: objSchemaModelFields
		}
	};
	
	//console.log(objSchema);
	
	
	$("#" + strMainGridDiv).kendoGrid({
		dataSource: {
			data: dashData,
			schema: objSchema,
			pageSize: 50
		},
		dataBound: function(e) {
			//if it is unread then make it bold!
			var thisKendoGrid = e.sender;
			//console.log(e);
			var dataItems = thisKendoGrid.items();
			dataItems.each(function (index) {
				var dataItem = thisKendoGrid.dataItem(this);
				if (dataItem.IsUnread == 1 || dataItem.ISUNREAD == 1) { //IsUnread is our special field from SQL.
					this.className += " arc_boldGridRow";
				}
			});
			//lastly, hide our isunread column if it exists.
			HideIsUnreadColumn(thisKendoGrid);
		},
		columns: arrColumns,
		toolbar: kendo.template(strHtmlTemplate),
		//height: 550,
		sortable: true,
		filterable: true,
		groupable: true,
		//scrollable: false,
		columnMenu: true,
		resizable: true,
		pageable: {
			input: true,
			numeric: false
		},
		selectable: "row",
		reorderable: false,
		allowCopy: true,
	});
	
	//Set up our events for reset view, and checkboxes.
	$("#resetView").bind("click", function(e){
        ResetAllWorkGrid();
    });
	
	$("#cbxShowActivitiesInGrid").bind("click", function(e){
        UpdateGridWithNewData(false); //will include whether or not this is checked.
    });
	
	$("#cbxShowInactiveWorkItems").bind("click", function(e){
        UpdateGridWithNewData(false); //will include whether or not this is checked.
    });	
	
	//Add a click event so we can navigate to the selected item when clicked.
	var kendoGridElement = $("#" + strMainGridDiv).data('kendoGrid');

	$(kendoGridElement.tbody).on("click", "td", function (e) {
		var row = $(this).closest("tr");
		var col = $(this).closest("td");
		//Only do something if the clicked column was 0 or 1. Ignore 2+.
		if (col.index() > 1) {
			return; 
		}
		//console.log(row.index());
		//console.log(col.index());
		
		var thisItem = kendoGridElement.dataItem(row);
		var strThisWorkItemId = GetWorkItemIdFromDataItem(thisItem);
		if (strThisWorkItemId == null) {
			console.log("Failed to get a valid work item ID from row " + row.index() + " column " + col.index() + ". Navigation will be disabled." );
			return;
		}
		
		//Navigate to this workitem id. e.g. http://scsm02/Search/GetSearchObjectByWorkItemID?searchText=IR111
		var strUrl = "/Search/GetSearchObjectByWorkItemID?searchText=" + strThisWorkItemId
		
		$.ajax({
			url: strUrl,
			type: "GET",
			async: true,
			success: function (data) {
				var strWiUrl = data; //GetSearchObjectByWorkItemID returns a string.
				window.open(strWiUrl, '_blank');
			}
		});
		
		
		
		
		//var rowIdx = $("tr", kendoGridElement.tbody).index(row);
		//var colIdx = $("td", row).index(this);
		//console.log(rowIdx + '-' + colIdx);
	});
	
	function HideIsUnreadColumn(kendoGridElement) {
		for(var i = 0; i < kendoGridElement.columns.length; i++) {
			
			if (kendoGridElement.columns[i].field.toUpperCase() == "ISUNREAD" ) { //Leave this grid alone entirely. 
				kendoGridElement.indexToHide = i;
				kendoGridElement.hideColumn(i);
				//HideKendoGridColumn(kendoGridElement);
				return;
			}
			
		}
	}
	
	function HideKendoGridColumn(kendoGridElement) {
		//Because for dashboard pages in Portal 9.0.13, 8.2.1, 9.3.4+, kendoGridElement.hideColumn(indexWithGuid) is sometimes broken.
		
		var gridElement = $(kendoGridElement.element);
		var indexToHide = kendoGridElement.indexToHide;
		
		kendoGridElement.bind("dataBound", HideFirstColumnInThisKendoGrid);
		kendoGridElement.bind("filter", HideFirstColumnInThisKendoGrid);
		kendoGridElement.bind("sort", HideFirstColumnInThisKendoGrid);
		
		//call it once to hide it.
		HideFirstColumnInThisKendoGrid(kendoGridElement);
		
		//And then one time only, create column elements within the table and assign a width.
		var headerTable = gridElement.find(".k-grid-header table");  //= $('.k-grid .k-grid-header table');
		var contentTable = gridElement.find(".k-grid-content table"); //$('.k-grid .k-grid-content table');
		

		// Reset the headers and columns to the same minimum width
		var col = headerTable.find('colgroup col:eq(' + indexToHide + ')').add(contentTable.find('colgroup col:eq(' + indexToHide + ')')); ////var col = headerTable.find('colgroup col:eq(0)').add(contentTable.find('colgroup col:eq(0)'));
		col.css('width', "0px");
		
		
		function HideFirstColumnInThisKendoGrid(e) {
			//Is e an element, or an existing kendo grid?
			var kendoGrid = null;
			
			if (e.dataSource == null)  //it's an element
				kendoGrid = e.sender;
			else
				kendoGrid = e; //its already a kendo grid from the parameter.
			
			var htmlElement = $(kendoGrid.element);
			var indexToHide = kendoGrid.indexToHide
			
			
			htmlElement.find("table").find("tr").each(function () {
				$(this).children("td:eq(" + indexToHide + ")").children().css("display", "none"); //$(this).children("td:eq(0)").html("");
			});
		}
	}
	
}

function GetWorkItemIdFromDataItem(dataItem) {
	var kendoGridElement = $("#" + strMainGridDiv).data('kendoGrid');
	//Get the first column name that has "Id" in it. A little bit lazy, but it's semi-OOB behavior.
	var strIdColumnName = null;
	for(var i=0; i< kendoGridElement.columns.length; i++) {
		if (kendoGridElement.columns[i].field.toLowerCase().indexOf("id") > -1) {
			return dataItem[kendoGridElement.columns[i].field];
		}
	}
}

function UpdateGridWithNewData(blnClearFilter) {
	
	var strShowActivities = "0";
	if ($("#cbxShowActivitiesInGrid")[0].checked == true) {
		strShowActivities = "1";
	}
	
	var strShowInactive = "0";
	if ($("#cbxShowInactiveWorkItems")[0].checked == true) {
		strShowInactive = "1";
	}
	
	//Do another API call, using our new parameters.
	//Do our API call potentially with two params. SHOWACTIVITIES and SHOWINACTIVE
	//http://scsm02/api/v3/Dashboard/GetDashboardDataById/?dateFilterType=NoFilter&priorityId=3&queryId=b6aac3c1-d278-a21e-49c5-bbf0303b90d9
	$.ajax({
		url: "/api/v3/Dashboard/GetDashboardDataById/?dateFilterType=NoFilter" + "&queryId=" + mainDataSourceGuid + 
				"&SHOWACTIVITIES=" + strShowActivities + 
				"&SHOWINACTIVE=" + strShowInactive
				,
		type: "GET",
		async: false,
		success: function (data) {
			ApplyDataToKendoGrid(data, blnClearFilter) 
		}
	});
	
	//console.log("strShowActivities=" + strShowActivities + " ; and strShowInactive=" + strShowInactive);
	
	function ApplyDataToKendoGrid(newData, blnClearFilter) {
		var kendoGridElement = $("#" + strMainGridDiv).data('kendoGrid'); //...as a kendo widget
		var newDataSource = new kendo.data.DataSource ({
			data: newData,
			pageSize: 50
		});
		//Update the data of the existing datasource.
		//console.log(newData);
		
		if (blnClearFilter != true) {
			//Save the previous filter.
			var previousFilter = kendoGridElement.dataSource.filter();
			//Set the previous filter.
			newDataSource.filter(previousFilter);
		}
		//Set the new datasource.
		kendoGridElement.setDataSource(newDataSource);
		kendoGridElement.dataSource.read();
		kendoGridElement.refresh();
	}
	
}
	
//helper function that lets us easily get the value of our URL parameter(s) when specified by name.
//getUrlParam(strParamName)  will return the value that the parameter strParamName
function getUrlParam(name){
	var results = new RegExp('[\?&]' + name + '=([^&#]*)').exec(window.location.href);
	if (results == null){
	   return null;
	}
	else{
	   return results[1] || 0;
	}
}

function ResetAllWorkGrid() {
		
	$("#cbxShowActivitiesInGrid").prop("checked", true);
	$("#cbxShowInactiveWorkItems").prop("checked", false);
	
	UpdateGridWithNewData(true); //clear the filter.
	
}

