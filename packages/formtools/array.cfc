<cfcomponent extends="field" name="array" displayname="array" hint="Used to liase with Array type fields"> 


	<cfimport taglib="/farcry/farcry_core/tags/webskin/" prefix="ws" >

		

	<cffunction name="edit" access="public" output="true" returntype="string" hint="This is going to called from ft:object and will always be passed 'typename,stobj,stMetadata,fieldname'.">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stObject" required="true" type="struct" hint="The object of the record that this field is part of.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		<cfargument name="fieldname" required="true" type="string" hint="This is the name that will be used for the form field. It includes the prefix that will be used by ft:processform.">

		<cfset var returnHTML = "" />
		<cfset var stobj = structnew() / >
		<cfset var stJoinObjects = structNew() /> <!--- This will contain a structure of object components that match the ftJoin list from the metadata --->
		

		<!---
		<cfset var oFourQ = createObject("component","farcry.fourq.fourq")><!--- TODO: this needs to be removed when we add typename to array tables. ---> 
		 --->
		
		<cfparam name="arguments.stMetadata.ftLibrarySelectedMethod" default="LibrarySelected">
		<cfparam name="arguments.stMetadata.ftLibrarySelectedListClass" default="thumbNailsWrap">
		<cfparam name="arguments.stMetadata.ftLibrarySelectedListStyle" default="">

		<!--- An array type MUST have a 'ftJoin' property --->
		<cfif not structKeyExists(arguments.stMetadata,"ftJoin") or not len(arguments.stMetadata.ftJoin)>
			<cfreturn "">
		</cfif>
		
		<cfset stJoinObjects = StructNew() />
		
		<!--- Create each of the the Linked Table Types as an object  --->
		<cfloop list="#arguments.stMetadata.ftJoin#" index="i">			
			<cfset stJoinObjects[i] = createObject("component",application.types[i].typepath)>
		</cfloop>

		<!--- Make sure scriptaculous libraries are included. --->
		<cfset Request.InHead.ScriptaculousDragAndDrop = 1>
		<cfset Request.InHead.ScriptaculousEffects = 1>	
		
			
		<cfquery datasource="#application.dsn#" name="qArrayField">
		SELECT *
		FROM #arguments.typename#_#arguments.stMetaData.Name#
		WHERE parentID = '#arguments.stObject.objectID#'
		ORDER BY seq
		</cfquery>	
		
		
		
		<cfset ULID = "#arguments.fieldname#_list"><!--- ID of the unordered list. Important to use this so that the object can be referenced even if their are multiple objects referencing the same field. --->
		
		<cfsavecontent variable="returnHTML">
			
			
<!---			<cfloop from ="1" to="#arrayLen(arguments.stObject[arguments.stMetaData.Name])#" index="i">
				<cfif isStruct(arguments.stObject[arguments.stMetaData.Name][i]) AND structKeyExists(arguments.stObject[arguments.stMetaData.Name][i],"data")>
					<cfset lArrayObjectIDs = ListAppend(lArrayObjectIDs,arguments.stObject[arguments.stMetaData.Name][i].data)>
				<cfelse>
					<cfset lArrayObjectIDs = ListAppend(lArrayObjectIDs,arguments.stObject[arguments.stMetaData.Name][i])>
				</cfif>
				
			</cfloop>	 --->	
			
			<!--- Contains a list of objectID's currently associated with this field' --->
			<cfoutput><input type="hidden" id="#arguments.fieldname#" name="#arguments.fieldname#" value="#valuelist(qArrayField.data)#" /></cfoutput>
			
			
			<cfif qArrayField.Recordcount>
				<cfoutput><div id="#ULID#" class="#arguments.stMetadata.ftLibrarySelectedListClass#" style="#arguments.stMetadata.ftLibrarySelectedListStyle#"></cfoutput>
					<cfloop query="qArrayField">
						<cfoutput><div id="#arguments.fieldname#_#qArrayField.data#">
							<img src="#application.url.farcry#/images/dragbar.gif" class="#ULID#handle" style="cursor:move;" align="center">
							<div></cfoutput>
							<!---
							<!--------------------------------------------------------------- 
							Need to determine the type of the object.
							TODO: array tables will include a typename field by default so we know what type they are and will not need to lookup the refObjects table.
							 --------------------------------------------------------------->
							<cfset typeName = oFourQ.findType(objectid=i) />
							 --->	
							<cfset stobj = stJoinObjects[qArrayField.typename].getData(objectid=qArrayField.data)>
							<cfif FileExists("#application.path.project#/webskin/#qArrayField.typename#/#arguments.stMetadata.ftLibrarySelectedMethod#.cfm")>
								<cfset stJoinObjects[qArrayField.typename].getDisplay(stObject=stobj, template="#arguments.stMetadata.ftLibrarySelectedMethod#") />
							<cfelse>
								<cfif isDefined("stobj.label") AND len(stobj.label)>
									<cfoutput>#stobj.Label#</cfoutput>
								<cfelse>
									<cfoutput>#stobj.ObjectID#</cfoutput>
								</cfif>
							</cfif>
											
							<cfoutput><a href="##" onclick="new Effect.Fade($('#arguments.fieldname#_#qArrayField.data#'));Element.remove('#arguments.fieldname#_#qArrayField.data#');$('#arguments.fieldname#').value = Sortable.sequence('#ULID#');update_#arguments.fieldname#('sort',$('#arguments.fieldname#')); return false;"><img src="#application.url.farcry#/images/crystal/22x22/actions/button_cancel.png" style="width:16px;height:16px;" /></a>
							</div>
						</div></cfoutput>
					</cfloop>
				<cfoutput></div></cfoutput>
			
				<cfoutput>
				<script type="text/javascript" language="javascript" charset="utf-8">					
				// <![CDATA[
					  Sortable.create('#ULID#',
					  	{ghosting:false,constraint:false,hoverclass:'over',handle:'#ULID#handle',constraint:'vertical',tag:'div',
					    onChange:function(element){
					    	$('#arguments.fieldname#').value = Sortable.sequence('#ULID#');	
					    },
					    onUpdate:function(element){					
				   			update_#arguments.fieldname#('sort',element);
					    }
					    
					  });
					// ]]>	
				
				</script>
			</cfoutput>
			
			<cfelse>
				<cfoutput>&nbsp;</cfoutput> 
			</cfif>
			
			<cfoutput>	
			<script type="text/javascript" language="javascript" charset="utf-8">
			function update_#arguments.fieldname#_wrapper(HTML){
				$('#arguments.fieldname#-wrapper').innerHTML = HTML;
				// <![CDATA[
					  Sortable.create('#ULID#',
					  {ghosting:false,constraint:false,hoverclass:'over',handle:'#ULID#handle',constraint:'vertical',tag:'div',
					    onChange:function(element){
					    	$('#arguments.fieldname#').value = Sortable.sequence('#ULID#');	
					    },
					    onUpdate:function(element){					
				   			update_#arguments.fieldname#('sort',element);
					    }
					  });
					// ]]>									 
			}
			
			function update_#arguments.fieldname#(action,element){
				new Ajax.Updater('#arguments.fieldname#-wrapper', '/farcry/facade/library.cfc?method=ajaxUpdateArray', {
						//onLoading:function(request){Element.show('indicator')}, 
						onComplete:function(request){
	
							update_#arguments.fieldname#_wrapper(request.responseText);	
							opener.update_#arguments.fieldname#_wrapper(request.responseText);						
							Effect.Fade(element, {from:0.2,to:0.2});
							// <![CDATA[
								  Sortable.create('#arguments.fieldname#_list',
								  	{ghosting:false,constraint:false,hoverclass:'over',handle:'#arguments.fieldname#_listhandle',constraint:'vertical',tag:'div',
								    onChange:function(element){
								    	$('#arguments.fieldname#').value = Sortable.sequence('#arguments.fieldname#_list')
								    }
								    
								  });
								// ]]>	
														
						}, 
						parameters:'Action=' + action + '&LibraryType=Array&primaryObjectID=#arguments.stObject.ObjectID#&primaryTypename=#arguments.typename#&primaryFieldname=#arguments.stMetaData.Name#&primaryFormFieldname=#arguments.fieldname#&WizzardID=&DataObjectID=' + encodeURIComponent($('#arguments.fieldname#').value) + '&DataTypename=#ListFirst(arguments.stMetadata.ftJoin)#', evalScripts:true, asynchronous:true
					})
			}
			
			
				
			</script>
			</cfoutput>		
			
		
		</cfsavecontent>

		
 		<cfreturn ReturnHTML>

	</cffunction>
	
	<cffunction name="display" access="public" output="false" returntype="string" hint="This will return a string of formatted HTML text to display.">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stObject" required="true" type="struct" hint="The object of the record that this field is part of.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		<cfargument name="fieldname" required="true" type="string" hint="This is the name that will be used for the form field. It includes the prefix that will be used by ft:processform.">

		<cfset var returnHTML = ""/>

		<cfparam name="arguments.stMetadata.ftLibrarySelectedMethod" default="Selected">
		<cfparam name="arguments.stMetadata.ftLibrarySelectedListClass" default="thumbNailsWrap">
		<cfparam name="arguments.stMetadata.ftLibrarySelectedListStyle" default="">
		
		<!--- We need to get the Array Field Items as a query --->
		<cfset o = createObject("component",application.types[arguments.typename].typepath)>
		<cfset q = o.getArrayFieldAsQuery(objectid="#arguments.stObject.ObjectID#", Typename="#arguments.typename#", Fieldname="#stMetadata.Name#", ftJoin="#stMetadata.ftJoin#")>
	
		<cfset stJoinObjects = StructNew() />
		
		<!--- Create each of the the Linked Table Types as an object  --->
		<cfloop list="#arguments.stMetadata.ftJoin#" index="i">			
			<cfset stJoinObjects[i] = createObject("component",application.types[i].typepath)>
		</cfloop>

		
		<cfsavecontent variable="returnHTML">
		<cfoutput>
				
			<cfset ULID = "#arguments.fieldname#_list">
			
			<cfif q.RecordCount>
				<div id="#ULID#" class="#arguments.stMetadata.ftLibrarySelectedListClass#" style="#arguments.stMetadata.ftLibrarySelectedListStyle#">
					<cfloop query="q">
						<!---<li id="#arguments.fieldname#_#q.objectid#"> --->
							
							<div>
							<cfset stobj = stJoinObjects[q.typename].getData(objectid=q.data) />
							<cfif FileExists("#application.path.project#/webskin/#q.typename#/#arguments.stMetadata.ftLibrarySelectedMethod#.cfm")>
								<cfset html = stJoinObjects[q.typename].getView(stObject=stobj,template="#arguments.stMetadata.ftLibrarySelectedMethod#") />
								#html#
								
								<!---<cfinclude template="/farcry/#application.applicationname#/webskin/#q.typename#/#arguments.stMetadata.ftLibrarySelectedMethod#.cfm"> --->
							<cfelse>
								#stobj.label#
							</cfif>
							</div>
													
						<!---</li> --->
					</cfloop>
				</div>
			</cfif>

				
		</cfoutput>
		</cfsavecontent>

		<cfreturn returnHTML>
	</cffunction>


	<cffunction name="validate" access="public" output="true" returntype="struct" hint="This will return a struct with bSuccess and stError">
		<cfargument name="ObjectID" required="true" type="UUID" hint="The objectid of the object that this field is part of.">
		<cfargument name="Typename" required="true" type="string" hint="the typename of the objectid.">
		<cfargument name="stFieldPost" required="true" type="struct" hint="The fields that are relevent to this field type.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		
		<cfset var stResult = structNew()>		
		<cfset stResult.bSuccess = true>
		<cfset stResult.value = "">
		<cfset stResult.stError = StructNew()>
		
		<!--- --------------------------- --->
		<!--- Perform any validation here --->
		<!--- --------------------------- --->
		
		
		<cfset aField = ArrayNew(1)>				
		<cfloop list="#stFieldPost.value#" index="i">
			<cfset ArrayAppend(aField,i)>
		</cfloop>
		
		<cfif not len(arguments.typename)>
			<cfset q4 = createObject("component","farcry.fourq.fourq")>
			<cfset arguments.typename = q4.findType(objectid=arguments.objectid)>
		</cfif>
		
		
		<cfset oPrimary = createObject("component",application.types[arguments.Typename].typepath)>
		<cfset variables.tableMetadata = createobject('component','farcry.fourq.TableMetadata').init() />
		<cfset tableMetadata.parseMetadata(md=getMetadata(oPrimary)) />		
		<cfset stFields = variables.tableMetadata.getTableDefinition() />
		<cfset o = createObject("component","farcry.fourq.gateway.dbGateway").init(dsn=application.dsn,dbowner="")>
		<cfset aProps = o.createArrayTableData(tableName=Typename & "_" & arguments.stMetadata.name,objectid=arguments.ObjectID,tabledef=stFields[arguments.stMetadata.name].Fields,aprops=aField)>


		<cfset stResult.value = aField>

		<!--- ----------------- --->
		<!--- Return the Result --->
		<!--- ----------------- --->
		<cfreturn stResult>
		
	</cffunction>
		
</cfcomponent> 