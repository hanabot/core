test<cfcomponent displayname="FarcryUD User" hint="Used by FarcryUD to store user information" extends="types" output="false" description="Stores login information about a FarCry User Directory user, and the groups they are members of">
	<cfproperty name="userid" type="string" default="" hint="The unique id for this user. Used for logging in" ftSeq="1" ftFieldset="" ftLabel="User ID" ftType="string" bLabel="true" />
	<cfproperty name="password" type="string" default="" hint="" ftSeq="2" ftFieldset="" ftLabel="Password" ftType="password" ftRenderType="confirmpassword" ftShowLabel="false" />
	<cfproperty name="userstatus" type="string" default="invactive" hint="The status of this user" ftSeq="3" ftFieldset="" ftLabel="User status" ftType="list" ftList="active:Active,inactive:Inactive,pending:Pending" />
	<cfproperty name="aGroups" type="array" default="" hint="The groups this member is a member of" ftSeq="4" ftFieldset="" ftLabel="Groups" ftType="array" ftJoin="farGroup" />
	<cfproperty name="lGroups" type="longchar" default="" hint="The groups this member is a member of (list generated automatically)" ftLabel="Groups" ftType="arrayList" ftArrayField="aGroups" ftJoin="farGroup" />
	
	<cffunction name="getByUserID" access="public" output="false" returntype="struct" hint="Returns the data struct for the specified user id">
		<cfargument name="userid" type="string" required="true" hint="The user id" />
		
		<cfset var stResult = structnew() />
		<cfset var qUser = "" />
		
		<cfquery datasource="#application.dsn#" name="qUser">
			select	*
			from	#application.dbowner#farUser
			where	lower(userid)=<cfqueryparam cfsqltype="cf_sql_varchar" value="#lcase(arguments.userid)#" />
		</cfquery>
		
		<cfif qUser.recordcount>
			<cfset stResult = getData(qUser.objectid) />
		</cfif>
		
		<cfreturn stResult />
	</cffunction>
	
	<cffunction name="addGroup" access="public" output="false" returntype="void" hint="Adds this user to a group">
		<cfargument name="user" type="string" required="true" hint="The user to add" />
		<cfargument name="group" type="string" required="true" hint="The group to add to" />
		
		<cfset var stUser = structnew() />
		<cfset var stGroup = structnew() />
		<cfset var oGroup = createObject("component", application.stcoapi["farGroup"].packagePath) />
		<cfset var groupID = oGroup.getID(arguments.group) />
		<cfset var i = 0 />
		
		<!--- Get the user by objectid or userid --->
		<cfif isvalid("uuid",arguments.user)>
			<cfset stUser = getData(arguments.user) />
		<cfelse>
			<cfset stUser = getByUserID(arguments.user) />
		</cfif>
	
		<cfset stGroup = oGroup.getData(objectid="#groupID#") />
		<cfset arguments.group = stGroup.objectid />
		
		<!--- Check to see if they are already a member of the group --->
		<cfparam name="stUser.aGroups" default="#arraynew(1)#" />
		<cfloop from="1" to="#arraylen(stUser.aGroups)#" index="i">
			<cfif stUser.aGroups[i] eq arguments.group>
				<cfset arguments.group = "" />
			</cfif>
		</cfloop>
		
		<cfif len(arguments.group)>
			<cfset arrayappend(stUser.aGroups,arguments.group) />
			<cfset setData(stProperties=stUser) />
		</cfif>
	</cffunction>

	<cffunction name="removeGroup" access="public" output="false" returntype="void" hint="Removes this user from a group">
		<cfargument name="user" type="string" required="true" hint="The user to add" />
		<cfargument name="group" type="string" required="true" hint="The group to add to" />
		
		<cfset var stUser = structnew() />
		<cfset var i = 0 />
		
		<!--- Get the user by objectid or userid --->
		<cfif isvalid("uuid",arguments.user)>
			<cfset stUser = getData(arguments.user) />
		<cfelse>
			<cfset stUser = getByUserID(arguments.user) />
		</cfif>
		
		<!--- Check to see if they are a member of the group --->
		<cfparam name="stUser.aGroups" default="#arraynew(1)#" />
		<cfloop from="#arraylen(stUser.aGroups)#" to="1" index="i" step="-1">
			<cfif stUser.aGroups[i] eq arguments.group>
				<cfset arraydeleteat(stUser.aGroups,i) />
			</cfif>
		</cfloop>
		
		<cfset oUser.setData(stProperties=stUser) />
	</cffunction>

	<cffunction name="setData" access="public" output="true" hint="Update the record for an objectID including array properties.  Pass in a structure of property values; arrays should be passed as an array.">
		<cfargument name="stProperties" required="true">
		<cfargument name="user" type="string" required="true" hint="Username for object creator" default="">
		<cfargument name="auditNote" type="string" required="true" hint="Note for audit trail" default="Updated">
		<cfargument name="bAudit" type="boolean" required="No" default="1" hint="Pass in 0 if you wish no audit to take place">
		<cfargument name="dsn" required="No" default="#application.dsn#">
		<cfargument name="bSessionOnly" type="boolean" required="false" default="false"><!--- This property allows you to save the changes to the Temporary Object Store for the life of the current session. ---> 
		<cfargument name="bAfterSave" type="boolean" required="false" default="true" hint="This allows the developer to skip running the types afterSave function.">	
		
		<cfset var stUser = getData(objectid=arguments.stProperties.objectid) />
		<cfset var oProfile = createObject("component", application.stcoapi["dmProfile"].packagePath) />
		<cfset var stUsersProfile = structNew() />
		
		<cfif application.security.userdirectories.CLIENTUD.bEncrypted and arguments.stProperties.password neq stUser.password>
			<cfset arguments.stProperties.password = hash(arguments.stProperties.password) />
		</cfif>
		
		<!--- This will create the users default profile if one does not yet exist --->
		<cfif not arguments.bSessionOnly>			
			<cfset stUsersProfile = oProfile.getProfile(userName=stUser.userid) />
			
			<cfif not stUsersProfile.bInDB>
				<cfset stUsersProfile.objectid = createUUID() />
				<cfset oProfile.setData(stProperties=stUsersProfile) />
			</cfif>
		</cfif>		
		
		<cfreturn super.setData(arguments.stProperties,arguments.user,arguments.auditNote,arguments.bAudit,arguments.dsn,arguments.bSessionOnly,arguments.bAfterSave) />
		
	</cffunction>
	
	<cffunction name="createData" access="public" returntype="any" output="false" hint="Creates an instance of an object">
		<cfargument name="stProperties" type="struct" required="true" hint="Structure of properties for the new object instance">
		<cfargument name="user" type="string" required="true" hint="Username for object creator" default="">
		<cfargument name="auditNote" type="string" required="true" hint="Note for audit trail" default="Created">
		<cfargument name="dsn" required="No" default="#application.dsn#"> 
		
		<cfif application.security.userdirectories.CLIENTUD.bEncrypted>
			<cfset arguments.stProperties.password = hash(arguments.stProperties.password) />
		</cfif>
		
		<cfreturn super.createData(arguments.stProperties,arguments.user,arguments.auditNote,arguments.dsn) />
	</cffunction>
	
	<cffunction name="ftValidateUserID" access="public" output="true" returntype="struct" hint="This will return a struct with bSuccess and stError">
		<cfargument name="objectid" required="true" type="string" hint="The objectid of the object that this field is part of.">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stFieldPost" required="true" type="struct" hint="The fields that are relevent to this field type.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		
		<cfset var stResult = structNew()>	
		<cfset var qDuplicate = queryNew("blah")>		
		<cfset stResult = createObject("component", application.formtools["field"].packagePath).passed(value=stFieldPost.Value) />
		
		<!--- --------------------------- --->
		<!--- Perform any validation here --->
		<!--- --------------------------- --->	
		<cfquery datasource="#application.dsn#" name="qDuplicate">
		SELECT objectid from farUser
		WHERE upper(userid) = '#ucase(stFieldPost.Value)#'
		</cfquery>
		
		<cfif qDuplicate.RecordCount>
			<!--- DUPLICATE USER --->
			<cfset stResult = createObject("component", application.formtools["field"].packagePath).failed(value="#arguments.stFieldPost.value#", message="The userid you have selected is already taken.") />
		</cfif>
	
		<!--- ----------------- --->
		<!--- Return the Result --->
		<!--- ----------------- --->
		<cfreturn stResult>
		
	</cffunction>
	
</cfcomponent>