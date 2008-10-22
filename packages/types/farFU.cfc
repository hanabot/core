<cfcomponent displayname="FarCry Friendly URL Table" hint="Manages FarCry Friendly URL's" extends="types" output="false" bDocument="true" scopelocation="application.fc.factory.farFU">
	<cfproperty ftSeq="1" name="refobjectid" type="uuid" default="" hint="stores the objectid of the related object" ftLabel="Ref ObjectID" />
	<cfproperty ftSeq="2" name="friendlyURL" type="string" default="" hint="The Actual Friendly URL" ftLabel="Friendly URL" />		
	<cfproperty ftSeq="3" name="queryString" type="string" default="" hint="The query string that will be parsed and placed in the url scope of the request" ftLabel="Query String" />		
	<cfproperty ftSeq="4" name="fuStatus" type="numeric" default="" hint="Status of the Friendly URL." ftType="list" ftList="-1:exception,0:archived,1:active,2:permenant" ftLabel="Status" />		


	<cffunction name="onAppInit" returntype="any" access="public" output="false" hint="Initializes the friendly url scopes and returns a copy of this initialised object">

		<cfset variables.stMappings = structNew() />
		<cfset variables.stLookup = structNew() />
		<cfset variables.stExclusion = structNew() />
		
		<cfset setupCoapiAlias() />
		<cfset setupMappings() />		
		
		<cfreturn this />
		
	</cffunction>
	

	<cffunction name="isUsingFU" returnType="boolean" access="public" output="false" hint="Returns whether the system should use Friendly URLS">
		
		<cfif not structKeyExists(variables, "bUsingFU")>
			<cfset variables.bUsingFU = pingFU() />
		</cfif>
		
		<cfreturn variables.bUsingFU />
	</cffunction>
	
	<cffunction name="turnOn" returnType="boolean" access="public" output="false" hint="Returns whether the system should use Friendly URLS">
		
		<cfset variables.bUsingFU = true />
		
		<cfreturn variables.bUsingFU />
	</cffunction>
	
	<cffunction name="turnOff" returnType="boolean" access="public" output="false" hint="Returns whether the system should use Friendly URLS">
		
		<cfset variables.bUsingFU = false />
		
		<cfreturn variables.bUsingFU />
	</cffunction>
		
	
	<cffunction name="pingFU" returnType="boolean" access="public" output="false" hint="Pings a test friendly url to determine if Friendly URLS are available">
		
		<cfset var pingResponse = "" />
		<cfset var bAvailable = false />
		
		<cftry>
			<cfhttp url="http://#cgi.server_name##application.url.webroot#/pingFU" throwonerror="true" timeout="1" port="#cgi.server_port#" result="pingResponse" />
		
			<cfif findNoCase("PING FU SUCCESS", pingResponse.Filecontent)>
				<cfset bAvailable = true />
			</cfif>
			 
			<cfcatch type="any">
				<cfset bAvailable = false />
			</cfcatch>
		</cftry>
		
		<cfreturn bAvailable />
	</cffunction>
	
	
	<cffunction name="migrate">
		<cfquery datasource="#application.dsn#" name="qLegacy">
		SELECT * FROM reffriendlyURL
		</cfquery>
		<cfset lLegacyFields = qLegacy.columnList />
		<cfloop query="qLegacy">
			<cfset stProps = structNew() />
			<cfloop list="#lLegacyFields#" index="i">
				<cfset stProps[i] = qLegacy[i][currentRow] />
			</cfloop>
			<cfset stProps.fuStatus = qLegacy.status />
			<cfset stProps.queryString = qLegacy.query_string />
			<cfset stResult = createData(stProperties="#stProps#") />
		</cfloop>
		
	</cffunction>
  
	<cffunction name="setupCoapiAlias" access="public" hint="Initializes the friendly url coapi aliases" output="false" returntype="void" bDocument="true">

		<cfset var i = "" />
			
		<cfset application.fc.fuID = structNew() />
		
		<cfif structKeyExists(application, "stCoapi")>
			<cfloop list="#structKeyList(application.stcoapi)#" index="i">	
				<cfset application.fc.fuID[application.stcoapi[i].fuAlias] = i />
			</cfloop>
		</cfif>		
		
	</cffunction>
	
	<cffunction name="setupMappings" access="public" hint="Updates the fu application scope with all the persistent FU mappings from the database." output="false" returntype="void" bDocument="true">

		<cfset var stLocal = StructNew()>
		<cfset var stResult = StructNew()>
		<cfset var stDeployResult = StructNew()>
		
		<!--- initialise fu scopes --->
		<cfset variables.stMappings = structNew() />
		<cfset variables.stLookup = structNew() />
		<cfset variables.fuExlusions = structNew() />
		
		<!--- Check to make sure the farFU table has been deployed --->
		<cftry>
			<cfquery datasource="#application.dsn#" name="stLocal.qPing">
			SELECT count(objectID)
			FROM #application.dbowner#farFU
			</cfquery>
		
			<cfcatch type="database">
				<cflock name="deployFarFUTable" timeout="30">
					<!--- The table has not been deployed. We need to deploy it now --->
					<cfset stDeployResult = deployType(dsn=application.dsn,bDropTable=true,bTestRun=false,dbtype=application.dbtype) />		
					<cfset migrate() />
				</cflock>		
			</cfcatch>
		</cftry>
		
		<!--- retrieve list of all FU that is not retired --->
		<cfswitch expression="#application.dbtype#">
		<cfcase value="ora,oracle">							
			<cfquery name="stLocal.q" datasource="#application.dsn#">
			SELECT	fu.friendlyurl, fu.refobjectid, fu.queryString
			FROM	#application.dbowner#farFU fu, 
					#application.dbowner#refObjects r
			WHERE	r.objectid = u.refobjectid
					AND fu.fuStatus > 0
			</cfquery>
		</cfcase>
		<cfdefaultcase>
			<cfquery name="stLocal.q" datasource="#application.dsn#">
			SELECT	fu.friendlyurl, fu.refobjectid, fu.queryString
			FROM	#application.dbowner#farFU fu inner join 
					#application.dbowner#refObjects r on r.objectid = fu.refobjectid
			WHERE	fu.fuStatus > 0
			</cfquery>
		</cfdefaultcase>
		</cfswitch>
		
		<!--- load mappings to application scope --->
		<cfloop query="stLocal.q">
			<!--- fu mappings --->
			<cfset variables.stMappings[stLocal.q.friendlyURL] = StructNew() />
			<cfset variables.stMappings[stLocal.q.friendlyURL].refobjectid = stLocal.q.refObjectID />
			<cfset variables.stMappings[stLocal.q.friendlyURL].queryString = stLocal.q.queryString />
			<!--- fu lookup --->
			<cfset variables.stLookup[stLocal.q.refobjectid] = stLocal.q.friendlyurl />
		</cfloop>



		<cfquery name="stLocal.qExclusion" datasource="#application.dsn#">
		SELECT	fu.friendlyurl, fu.refobjectid, fu.queryString
		FROM	#application.dbowner#farFU fu inner join 
				#application.dbowner#refObjects r on r.objectid = fu.refobjectid
		WHERE	fu.fuStatus = -1
		</cfquery>
		
		<!--- load exclusion mappings to application scope --->
		<cfloop query="stLocal.qExclusion">
			<!--- fu lookup --->
			<cfset variables.fuExlusions[stLocal.q.refobjectid] = stLocal.q.friendlyurl />
		</cfloop>
		
	</cffunction>
		

	<cffunction name="parseURL" returntype="void" access="public" output="false" hint="Parses the url.furl and places relevent keys into request.fc namespace.">
		
		<cfset var oFU = createObject("component","#application.packagepath#.farcry.fu") />
		<cfset var stFU = structNew() />
		<cfset var stURL = structNew() />	
		
		<cfif structKeyExists(url, "furl") AND len(url.furl) AND url.furl NEQ "/">
					
			<cfset stFU = getFUData(url.furl) />

			<cfif stFU.bSuccess>
			
				<!--- check if this friendly url is a retired link.: if not then show page --->
				<cfif stFU.redirectFUURL NEQ "">
					<cfheader statuscode="301" statustext="Moved permanently">
					<cfheader name="Location" value="#stFU.redirectFUURL#">
					<cfabort>
				<cfelse>
					<cfset request.fc.objectid = stFU.refobjectid>
					<cfloop index="iQstr" list="#stFU.queryString#" delimiters="&">
						<cfset url["#listFirst(iQstr,'=')#"] = listLast(iQstr,"=")>
					</cfloop>
				</cfif>
				
			<cfelse>
				
						
				<cfloop list="#url.furl#" index="i" delimiters="/">
					<cfif isUUID(i)>
						<cfset request.fc.objectid = i />
						
					<cfelse>
						<cfif structKeyExists(request.fc, "view")>
						
							<!--- Only check for other attributes once the type is determined. --->				
							<cfif len(application.coapi.coapiAdmin.getWebskinPath(typename="#request.fc.type#", template="#i#"))>
								<!--- THIS MEANS ITS A WEBSKIN --->
								<cfset request.fc.bodyView = i />
							</cfif>
								
				
						<cfelseif structKeyExists(request.fc, "type")>
						
							<!--- Only check for other attributes once the type is determined. --->				
							<cfif len(application.coapi.coapiAdmin.getWebskinPath(typename="#request.fc.type#", template="#i#"))>
								<!--- THIS MEANS ITS A WEBSKIN --->
								<cfset request.fc.view = i />
							</cfif>
							
				
						<cfelseif structKeyExists(application.stCoapi, "#i#")>
							<!--- CHECK FOR TYPENAME FIRST --->
							<cfset request.fc.type = i />
				
						<cfelseif structKeyExists(application.fc.fuID, "#i#")>
							<cfset request.fc.type = application.fc.fuID[i] />
						</cfif>	
					</cfif>	
			
							
							
				</cfloop>
			
			</cfif>
		</cfif>
		
	</cffunction>
	
	
	
	<cffunction name="getFUData" access="public" returntype="struct" hint="Returns a structure of internal data based on the FU passed in." output="false">
		<cfargument name="friendlyURL" type="string" required="Yes">
		<cfargument name="dsn" required="no" default="#application.dsn#"> 

		<cfset var stReturn = StructNew()>
		<cfset var stLocal = StructNew()>
		<cfset stReturn.bSuccess = 1>
		<cfset stReturn.message = "">
		<cfset stReturn.refObject = "">
		<cfset stReturn.queryString = "">
		<cfset stReturn.redirectFUURL = "">
		

		<!--- correct internal var for presence/absence of trailing slash in URL --->
		<cfif Right(arguments.friendlyURL,1) EQ "/">
			<cfset stLocal.strFriendlyURL_WSlash = arguments.friendlyURL>
			<cfset stLocal.strFriendlyURL = Left(arguments.friendlyURL,Len(arguments.friendlyURL)-1)>
		<cfelse>
			<cfset stLocal.strFriendlyURL_WSlash = arguments.friendlyURL & "/">
			<cfset stLocal.strFriendlyURL = arguments.friendlyURL>
		</cfif>

		<!--- check if the FU exists in the applictaion scope [currently active] --->
		<cfif StructKeyExists(variables.stMappings,stLocal.strFriendlyURL)>
			<cfset stReturn.refObjectID = variables.stMappings[stLocal.strFriendlyURL].refObjectID>
			<cfset stReturn.queryString = variables.stMappings[stLocal.strFriendlyURL].queryString>
		<cfelseif StructKeyExists(variables.stMappings,stLocal.strFriendlyURL_WSlash)>
			<cfset stReturn.refObjectID = variables.stMappings[stLocal.strFriendlyURL_WSlash].refObjectID>
			<cfset stReturn.queryString = variables.stMappings[stLocal.strFriendlyURL_WSlash].queryString>
		<cfelse> <!--- check in database [retired] .: redirect --->
			<cfquery datasource="#arguments.dsn#" name="stLocal.qGet">
			SELECT	fu.refobjectid
			FROM	#application.dbowner#farFU fu, 
					#application.dbowner#refObjects r
			WHERE	 r.objectid = fu.refobjectid
					AND 
						(fu.friendlyURL = <cfqueryparam value="#stLocal.strFriendlyURL#" cfsqltype="cf_sql_varchar">
						OR 	fu.friendlyURL = <cfqueryparam value="#stLocal.strFriendlyURL_WSlash#" cfsqltype="cf_sql_varchar">)
			ORDER BY fu.fuStatus DESC
			</cfquery>
			
			<cfif stLocal.qGet.recordCount>
				<!--- get the new friendly url for the retired friendly url --->
				<cfquery datasource="#application.dsn#" name="stLocal.qGetRedirectFU">
				SELECT	fu.refobjectid, fu.friendlyURL, fu.queryString, fu.fuStatus
				FROM	#application.dbowner#farFu fu, 
					    #application.dbowner#refObjects r 
				WHERE	r.objectid = fuu.refobjectid
						AND fu.refobjectid = <cfqueryparam value="#stLocal.qGet.refobjectid#" cfsqltype="cf_sql_varchar">
				ORDER BY fu.fuStatus DESC
				</cfquery>
				
				<cfif stLocal.qGetRedirectFU.recordCount>
					<cfif stLocal.qGetRedirectFU.fuStatus EQ 1 OR stLocal.qGetRedirectFU.fuStatus EQ 2>
						<cfset stReturn.refObjectID = stLocal.qGetRedirectFU.refObjectID>
						<cfset stReturn.queryString = stLocal.qGetRedirectFU.queryString>
						<!--- add to applicatiuon scope --->
						<cfset variables.stMappings[stLocal.qGetRedirectFU.friendlyURL] = StructNew()>
						<cfset variables.stMappings[stLocal.qGetRedirectFU.friendlyURL].refObjectID = stLocal.qGetRedirectFU.refObjectID>
						<cfset variables.stMappings[stLocal.qGetRedirectFU.friendlyURL].queryString = stLocal.qGetRedirectFU.queryString>
					<cfelse>
						<cfset stReturn.redirectFUURL = "http://" & cgi.server_name & stLocal.qGetRedirectFU.friendlyURL>
					</cfif>
				<cfelse>
					<cfset stReturn.bSuccess = 0>
					<cfset stReturn.message = "Sorry your requested page could not be found.">
				</cfif>
			<cfelse>
				<cfset stReturn.bSuccess = 0>
				<cfset stReturn.message = "Sorry your requested page could not be found.">
			</cfif>
		</cfif>

		<cfreturn stReturn>
	</cffunction>
	


	<cffunction name="rebuildFU" access="public" returntype="struct" hint="rebuilds friendly urls for a particular type" output="true">

		<cfargument name="typeName" required="true" type="string">
		
		<cfset var stLocal = structnew()>
		<cfset stLocal.returnstruct = StructNew()>
		<cfset stLocal.returnstruct.bSuccess = 1>
		<cfset stLocal.returnstruct.message = "">

		<cfquery name="stLocal.qList" datasource="#application.dsn#">
		SELECT	objectid, label
		FROM	#application.dbowner##arguments.typeName#
		WHERE	label != '(incomplete)'
		</cfquery>

		<!--- clean out any friendly url for objects that have been deleted --->
		<cfquery name="stLocal.qDelete" datasource="#application.dsn#">
		DELETE
		FROM	#application.dbowner#farFU
		WHERE	refobjectid NOT IN (SELECT objectid FROM #application.dbowner#refObjects)
		</cfquery>

		<!--- delete old friendly url for this type --->
		<cfquery name="stLocal.qDelete" datasource="#application.dsn#">
		DELETE
		FROM	#application.dbowner#farFU
		WHERE	refobjectid IN (SELECT objectid FROM #application.dbowner##arguments.typeName#)
		</cfquery>
		
		<cfset stLocal.iCounterUnsuccess = 0>
		<cftry>
			<cfloop query="stLocal.qList">
				<cfset stlocal.stInstance = getData(objectid=stLocal.qList.objectid,bShallow=true)>
				<cfset setFriendlyURL(stlocal.stInstance.objectid)>
			</cfloop>
			<cfcatch>
				<cfset stLocal.iCounterUnsuccess = stLocal.iCounterUnsuccess + 1>
			</cfcatch>
		</cftry>
		<cfset stLocal.iCounterSuccess = stLocal.qList.recordcount - stLocal.iCounterUnsuccess>
		<cfset stLocal.returnstruct.message = "#stLocal.iCounterSuccess# #arguments.typeName# rebuilt successfully.<br />">
 		<cfreturn stLocal.returnstruct>
	</cffunction>
	

	<cffunction name="setFriendlyURL" access="public" returntype="struct" hint="Default setfriendlyurl() method for content items." output="false">
		<cfargument name="objectid" required="true" type="uuid" hint="Content item objectid.">
		<cfargument name="typename" required="false" default="" type="string" hint="Content item typename if known.">
		
		<cfset var stReturn = StructNew()>
		<cfset var stobj = application.coapi.coapiUtilities.getContentObject(objectID="#arguments.objectid#", typename="#arguments.typename#") />
		<cfset var stFriendlyURL = StructNew()>
		<cfset var objNavigation = CreateObject("component", application.stcoapi['dmNavigation'].packagePath) />
		<cfset var qNavigation=querynew("parentid")>
		
		<!--- default return structure --->
		<cfset stReturn.bSuccess = 1>
		<cfset stReturn.message = "Set friendly URL for #arguments.objectid#.">

		<cfif not listcontains(application.config.fusettings.lExcludeObjectIDs,arguments.objectid)>
			<!--- default stFriendlyURL structure --->
			<cfset stFriendlyURL.objectid = stobj.objectid>
			<cfset stFriendlyURL.friendlyURL = "">
			<cfset stFriendlyURL.querystring = "">
		
			<!--- This determines the friendly url by where it sits in the navigation node  --->
			<cfset qNavigation = objNavigation.getParent(stobj.objectid)>
			
			<!--- if its got a tree parent, build from navigation folders --->
			<!--- TODO: this might be better done by checking for bUseInTree="true" 
						or remove it entirely.. ie let tree content have its own fu as well as folder fu
						or set up tree content to have like page1.cfm style suffixs
						PLUS need collision detection so don't overwrite another tree based content item fro utility nav
						PLUS need to exclude trash branch (perhaps just from total rebuild?
						GB 20060117 --->
			<cfif qNavigation.recordcount>
				<cfset stFriendlyURL.friendlyURL = createFUAlias(qNavigation.parentid)>
			
			<!--- otherwise, generate friendly url based on content type --->
			<cfelse> 
				<cfif StructkeyExists(application.stcoapi[stobj.typename],"fuAlias")>
					<cfset stFriendlyURL.friendlyURL = "/#application.stcoapi[stobj.typename].fuAlias#" />
				<cfelseif StructkeyExists(application.stcoapi[stobj.typename],"displayName")>
					<cfset stFriendlyURL.friendlyURL = "/#application.stcoapi[stobj.typename].displayName#" />
				<cfelse>
					<cfset stFriendlyURL.friendlyURL = "/#ListLast(application.stcoapi[stobj.typename].name,'.')#" />
				</cfif>
			</cfif>
			
			<!--- set friendly url in database --->
			<cfset stFriendlyURL.friendlyURL = stFriendlyURL.friendlyURL & "/#stobj.label#">
			<cfset setFU(stFriendlyURL.objectid, stFriendlyURL.friendlyURL, stFriendlyURL.querystring)>
			
			<cflog application="true" file="futrace" text="types.setFriendlyURL: #stFriendlyURL.friendlyURL#" />
		</cfif>
		
 		<cfreturn stReturn />
	</cffunction>
	

	<cffunction name="setMapping" access="private" returntype="boolean" hint="Writes FU to the database and updates the application.fu scopes. This can be a new or existing mapping." output="false">
<!--- 	
		TODO: 	this is a bastardisation of servlet FU (2.3) and rewrite engine FU (3.0)
				remove all servlet related code.. its rubbish now GB 20060117
 --->	
		<cfargument name="alias" required="yes" type="string">
		<cfargument name="mapping" required="yes" type="string">
		<cfargument name="querystring" required="no" type="string" default="">
		<cfargument name="bPermantLink" required="no" type="boolean" default="0" hint="used to set the FU to be either 1 or 2">
		
		<cfset var stLocal = StructNew()>
		<cfset stLocal.objectid = CreateUUID()>
		<cfset stLocal.friendlyURL = arguments.alias>
		<cfset stLocal.querystring = arguments.querystring>
		<cfif arguments.bPermantLink>
			<cfset stLocal.fuStatus = 2> <!--- permanent --->
		<cfelse>
			<cfset stLocal.fuStatus = 1> <!--- active --->
		</cfif>
		

		<cfif left(stLocal.friendlyURL,1) NEQ "/">
			<cfset stLocal.friendlyURL = "/#stLocal.friendlyURL#" />
		</cfif>
		
		<!--- parse the mapping variables to get objectid etc --->
		<cfset stLocal.lMapping = ListLast(arguments.mapping,"?")>
		<cfset stLocal.refObjectID = ListLast(stLocal.lMapping,"=")>
<!--- 		<cfset stLocal.friendlyURL_length = Len(stLocal.friendlyURL) - FindNoCase(application.config.fusettings.urlpattern,stLocal.friendlyURL) + 1>
		<cfset stLocal.friendlyURL = Right(stLocal.friendlyURL,stLocal.friendlyURL_length)> --->

		<!--- check if friendly url is currently active AND that no change has occured to the friendlyurl --->
		<cfquery name="qCheck" datasource="#application.dsn#">
		SELECT	r.objectid
		FROM	#application.dbowner#farFu u,
				#application.dbowner#refObjects r 
		WHERE	r.objectid = u.refobjectid
				AND u.refObjectID = <cfqueryparam value="#stLocal.refObjectID#" cfsqltype="cf_sql_varchar">
				AND u.friendlyurl = <cfqueryparam value="#stLocal.friendlyURL#" cfsqltype="cf_sql_varchar">
				AND u.fuStatus = <cfqueryparam value="#stLocal.fuStatus#" cfsqltype="cf_sql_integer">
		</cfquery>
		
		<cfif qCheck.recordCount EQ 0>
			<!--- get exitsing friendly ONLINE urls for the objectid --->
			<cfquery datasource="#application.dsn#" name="qCheckCurrent">
			SELECT	friendlyurl
			FROM	#application.dbowner#farFu u, 
					#application.dbowner#refObjects r 
			WHERE	r.objectid = u.refobjectid
					AND u.refObjectID = <cfqueryparam value="#stLocal.refObjectID#" cfsqltype="cf_sql_varchar">
					AND u.fuStatus = <cfqueryparam value="#stLocal.fuStatus#" cfsqltype="cf_sql_integer">
			</cfquery>

			<!--- remove from app scope --->
			<cfloop query="qCheckCurrent">
				<cfset StructDelete(variables.stMappings,qCheckCurrent.friendlyurl)>
			</cfloop>

			<!--- retire the existing friendlyurl that is not a permanent redirect {ie status = 2} --->
			<cfquery datasource="#application.dsn#" name="qUpdate">
			UPDATE	#application.dbowner#farFu
			SET		fuStatus = 0
			WHERE	refObjectID = <cfqueryparam value="#stLocal.refObjectID#" cfsqltype="cf_sql_varchar">
				AND fuStatus = <cfqueryparam value="#stLocal.fuStatus#" cfsqltype="cf_sql_integer">
			</cfquery>

			<cfset stNewFU = structNew() />
			<cfset stNewFU.objectid = stLocal.objectID />
			<cfset stNewFU.refobjectid = stLocal.refobjectid />
			<cfset stNewFU.refobjectid = stLocal.refobjectid />
			<cfset stNewFU.friendlyurl = stLocal.friendlyurl />
			<cfset stNewFU.queryString = stLocal.queryString />
			<cfset stNewFU.fuStatus = stLocal.fuStatus />
			
			<cfset stResult = createData(stProperties="#stNewFU#") />
			
			<!--- add to app scope --->
			<cfset variables.stMappings[stLocal.friendlyURL] = StructNew()>
			<cfset variables.stMappings[stLocal.friendlyURL].refobjectid = stNewFU.refObjectID>
			<cfset variables.stMappings[stLocal.friendlyURL].queryString = stNewFU.querystring>
			
			<!--- fu lookup --->
			<cfset variables.stLookup[stLocal.refobjectid] = stNewFU.friendlyURL>
		</cfif>

		<cfreturn true>
	</cffunction>		
	
	<cffunction name="deleteMapping" access="public" returntype="boolean" hint="Deletes a mapping and writes the map file to disk" output="No">
		<cfargument name="alias" required="yes" type="string">
		
		<cfquery datasource="#application.dsn#" name="qDelete">
		DELETE	
		FROM	#application.dbowner#farFu 				
		WHERE	friendlyURL = <cfqueryparam value="#arguments.alias#" cfsqltype="cf_sql_varchar">
		</cfquery>
		
		<cfset StructDelete(variables.stMappings,arguments.alias)>
		<!--- <cfset dataObject.removeMapping(arguments.alias)> --->
		<cfreturn true>
	</cffunction>
	

	<cffunction name="getFUstruct" access="public" returntype="struct" hint="Returns a structure of all friendly URLs, keyed on object id." output="No">
		<cfargument name="domain" required="no" type="string" default="#cgi.server_name#">
		
		<cfset var stMappings = setupMappings()>
		<cfset var stFU = structnew()>
		
		<cfloop collection="#stMappings#" item="i">
			<cfif findnocase(domain,i)>
				<cfset stFU[listgetat(stMappings[i],2,"=")] = "/" & listRest(i,'/')>
			</cfif>
		</cfloop>
		
		<cfreturn stFU>
	</cffunction>		
				
	<cffunction name="IsUUID" returntype="boolean" access="private" output="false" hint="Returns TRUE if the string is a valid CF UUID.">
		<cfargument name="str" type="string" default="" />
	
		<cfreturn REFindNoCase("^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{16}$", str) />
	</cffunction>
	
	
	<cffunction name="deleteAll" access="public" returntype="boolean" hint="Deletes all mappings and writes the map file to disk" output="No">
		
		<cfset var stLocal = structNew() />
		<!--- <cfset var mappings = getMappings()>
		<cfset var dom = "">
		<cfset var i = ""> --->
		<!--- loop over all entries and delete those that match domain --->
		
		<cfquery datasource="#application.dsn#" name="stLocal.qDelete">
		DELETE	
		FROM	#application.dbowner#farFu
		WHERE	fuStatus != 2
		</cfquery>
		
		<cfset setupMappings() />
		
		<cfreturn true>
	</cffunction>
	
	<cffunction name="deleteFU" access="public" returntype="boolean" hint="Deletes a mappings and writes the map file to disk" output="No" bDocument="true">
		<cfargument name="alias" required="yes" type="string" hint="old alias of object to delete">
		
		<cfset var dom = "">
		<cfset var sFUKey = "">		
		<cfset var mappings = structCopy(variables.stMappings)>
		
		<!--- loop over all domains --->
		<cfloop list="#application.config.fusettings.domains#" index="dom">
			<cfset sFUKey = "#dom##arguments.alias#">
			<cfset aFuKey = structFindKey(mappings,sFUKey,"one")>
			<cfif arrayLen(aFuKey)>
				<cfset deleteMapping(sFUKey)>
			</cfif>
		</cfloop>
		<!--- <cfset updateAppScope()> --->
		<cfreturn true>
	</cffunction>
		
		

   <cffunction name="createFUAlias" access="public" returntype="string" hint="Creates the FU Alias for a given objectid" output="no">
		<cfargument name="objectid" required="Yes">
		<cfargument name="bIncludeSelf" required="no" default="1">

		<cfset var stLocal = StructNew()>
		<cfset stLocal.qListAncestors = application.factory.oTree.getAncestors(objectid=arguments.objectid,bIncludeSelf=arguments.bIncludeSelf)>
		<cfset stLocal.returnString = "">

		<cfif stLocal.qListAncestors.RecordCount>
			<!--- remove root & home --->
			<cfquery dbtype="query" name="stLocal.qListNav">
			SELECT 	objectID
			FROM 	stLocal.qListAncestors
			WHERE 	nLevel >= 2
			ORDER BY nLevel
			</cfquery>
			
			<cfset stLocal.lNavID = ValueList(stLocal.qListNav.objectid)>
			<cfset stLocal.lNavID = ListQualify(stLocal.lNavID,"'")>

			<cfif stLocal.lNavID NEQ "" AND arguments.objectid NEQ application.navid.home>
				<!--- optimisation: get all dmnavgiation data to avoid a getData() call --->
				<cfswitch expression="#application.dbtype#">
				<cfcase value="ora,oracle">		
					<cfquery name="stLocal.qListNavAlias" datasource="#application.dsn#">
			    	SELECT	dm.objectid, dm.label, dm.fu 
			    	FROM	#application.dbowner#dmNavigation dm, #application.dbowner#nested_tree_objects nto
			    	WHERE	dm.objectid = nto.objectid
			    			AND dm.objectid IN (#preserveSingleQuotes(stLocal.lNavID)#)
			    	ORDER by nto.nlevel ASC
					</cfquery>
				</cfcase>
				<cfdefaultcase>
				<cfquery name="stLocal.qListNavAlias" datasource="#application.dsn#">
			    SELECT	dm.objectid, dm.label, dm.fu 
			    FROM	#application.dbowner#dmNavigation dm
			    JOIN #application.dbowner#nested_tree_objects nto on dm.objectid = nto.objectid
			    WHERE	dm.objectid IN (#preserveSingleQuotes(stLocal.lNavID)#)
			    ORDER by nto.nlevel ASC
				</cfquery>
				</cfdefaultcase>
				</cfswitch>
		
				<cfloop query="stLocal.qListNavAlias">
					<!--- check if has FU if so use it --->
					<cfif trim(stLocal.qListNavAlias.fu) NEQ "">
						<cfset stLocal.returnString = ListAppend(stLocal.returnString,trim(stLocal.qListNavAlias.fu))>
					<cfelse> <!--- no FU so use label --->
						<cfset stLocal.returnString = ListAppend(stLocal.returnString,trim(stLocal.qListNavAlias.label))>
					</cfif>
				</cfloop>
				
			</cfif>
		</cfif>
		
		<!--- change delimiter --->
		<cfset stLocal.returnString = listChangeDelims(stLocal.returnString,"/") />
		<!--- remove spaces --->
		<cfset stLocal.returnString = ReReplace(stLocal.returnString,' +','-',"all") />
		<cfif Right(stLocal.returnString,1) NEQ "/">
			<cfset stLocal.returnString = stLocal.returnString & "/">
		</cfif>

   		<cfreturn lcase(stLocal.returnString)>
	</cffunction>	
	
	<cffunction name="createAndSetFUAlias" access="public" returntype="string" hint="Creates and sets an the FU mapping for a given dmNavigation object. Returns the generated friendly URL." output="No">
		<cfargument name="objectid" required="true" hint="The objectid of the dmNavigation node" />
		<cfset var breadCrumb = "">

		<cfif arguments.objectid eq application.navid.home>
			<cfset breadcrumb = "" /><!--- application.config.fusettings.urlpattern --->
		<cfelse>
			<cfset breadcrumb = createFUAlias(objectid=arguments.objectid) />
		</cfif>
	
		<cfif breadCrumb neq "">
			<cfset setFU(objectid=arguments.objectid,alias=breadcrumb) />
		</cfif>
		<cfreturn breadCrumb />
	</cffunction>
	
	<cffunction name="createAll" access="public" returntype="boolean" hint="Deletes old mappings and creates new entries for entire tree, and writes the map file to disk" output="No">
		
		<!--- get nav tree --->
		<cfset var qNav = application.factory.oTree.getDescendants(objectid=application.navid.home, depth=50)>
		<cfset var qAncestors = "">
		<cfset var qCrumb = "">
		<cfset var breadCrumb = "">
		<cfset var oNav = createObject("component",application.types.dmNavigation.typepath)>
		<cfset var i = 0>

		<!--- remove existing fu's --->
		<cfset deleteALL()>
		<!--- set error template --->		
		<!--- <cfset setErrorTemplate("#application.url.webroot#")> --->
		<!--- set nav variable --->
		<!--- <cfset setURLVar("nav")> --->
		<!--- loop over nav tree and create friendly urls --->
		<cfloop query="qNav">
			<cfset createAndSetFUAlias(objectid=qNav.objectid) />
		</cfloop>

		<!--- create fu for home--->
		<!--- <cfset createAndSetFUAlias(objectid=application.navid.home) /> --->

		<cfset onAppInit() />
		<cfreturn true />
	</cffunction>
	
	<cffunction name="setFU" access="public" returntype="string" hint="Sets an fu" output="yes" bDocument="true">
		<cfargument name="objectid" required="yes" type="UUID" hint="objectid of object to link to">
		<cfargument name="alias" required="yes" type="string" hint="alias of object to link to">
		<cfargument name="querystring" required="no" type="string" default="" hint="extra querystring parameters">
		<cfargument name="bPermantLink" required="no" type="boolean" default="0" hint="used to set the FU to be either 1 or 2">
		
		<cfset var dom = "">
		<!--- replace spaces in title --->
		<cfset var newAlias = replace(arguments.alias,' ','-',"all")>
		<!--- replace duplicate dashes with a single dash --->
		<cfset newAlias = REReplace(newAlias,"-+","-","all")>
		<!--- replace the html entity (&amp;) with and --->
		<cfset newAlias = reReplaceNoCase(newAlias,'&amp;','and',"all")>
		<!--- remove illegal characters in titles --->
		<cfset newAlias = reReplaceNoCase(newAlias,'[,:\?##����]','',"all")>
		<!--- change & to "and" in title --->
		<cfset newAlias = reReplaceNoCase(newAlias,'[&]','and',"all")>
		<!--- prepend fu url pattern and add suffix --->
		<cfset newAlias = newAlias>
		<cfset newAlias = ReplaceNocase(newAlias,"//","/","All")>
		<cfset newAlias = LCase(newAlias)>
		<cfset newAlias = ReReplaceNoCase(newAlias,"[^a-z0-9/]"," ","all")>
		<cfset newAlias = ReReplaceNoCase(newAlias,"  "," ","all")>
		<cfset newAlias = Trim(newAlias)>
		<cfset newAlias = ReReplaceNoCase(newAlias," ","-","all")>		
		<!--- loop over domains and set fu ---> 
		<!--- <cfloop list="#application.config.fusettings.domains#" index="dom"> --->
			<cfset setMapping(alias=newAlias,mapping="#application.url.conjurer#?objectid=#arguments.objectid#",querystring=arguments.querystring,bPermantLink=bPermantLink)>
		<!--- </cfloop> --->
		<!--- <cfset updateAppScope()> --->
		<cflog application="true" file="futrace" text="fu.setfu">
	</cffunction>
	
	<cffunction name="getFU" access="public" returntype="string" hint="Retrieves fu for a real url, returns original ufu if non existent." output="yes" bDocument="true">
		<cfargument name="objectid" required="yes" type="string" hint="objectid of object to link to">
		<!--- <cfargument name="dom" required="yes" type="string" default="#cgi.server_name#"> --->
		
		<!--- set base URL --->
		<cfset var fuURL = "#application.url.conjurer#?objectid=#arguments.objectid#">
		
		<!--- if FU mappings are not in memory load them into memory.. --->
		<!--- TODO: wrong place for this! GB 20060117 --->
		<cfif NOT isDefined("variables.stMappings")>
			<cfset onAppInit()>
		</cfif>
		
		<!--- look up in memory cache --->
		<cfif structKeyExists(variables.stLookup, arguments.objectid)>
			<cfset fuURL = variables.stLookup[arguments.objectid]>
		
		<!--- if not in cache check the database --->
		<cfelse>
		<!--- <cftrace inline="true" text="fu db lookup!"> --->
			<!--- get friendly url based on the objectid --->
			<cfswitch expression="#application.dbtype#">
			<cfcase value="ora,oracle">					
				<cfquery datasource="#application.dsn#" name="qGet">
				SELECT	friendlyURL, refobjectid, queryString
				FROM	#application.dbowner#farFu u, 
						#application.dbowner#refObjects r 
				WHERE r.objectid = u.refobjectid
					AND u.refobjectid = <cfqueryparam value="#arguments.objectid#" cfsqltype="cf_sql_varchar">
					AND u.fuStatus != 0
				</cfquery>
			</cfcase>
			<cfdefaultcase>
				<cfquery datasource="#application.dsn#" name="qGet">
				SELECT	friendlyURL, refobjectid, queryString
				FROM	#application.dbowner#farFu u inner join 
						#application.dbowner#refObjects r on r.objectid = u.refobjectid
				WHERE
					refobjectid = <cfqueryparam value="#arguments.objectid#" cfsqltype="cf_sql_varchar">
					AND fuStatus != 0
				</cfquery>
			</cfdefaultcase>
			</cfswitch>
			<cfif qGet.recordCount>
				<cfset fuURL = "#qGet.friendlyURL#">
			</cfif>
		</cfif>
		
		<cfreturn fuURL>
	</cffunction>

	<cffunction name="fListFriendlyURL" access="public" returntype="struct" hint="returns a query of FU for a particular objectid" output="No">
		<cfargument name="objectid" required="yes" hint="Objectid of object" />
		<cfargument name="fuStatus" required="no" default="current" hint="status of friendly you want, [all (0,1,2), current (1,2), active (1), permanent (2), archived (0), exclusion(-1)]" />
			   
		<cfset var stLocal = StructNew()>
		<cfset stLocal.returnstruct = StructNew()>
		<cfset stLocal.returnstruct.bSuccess = 1>
		<cfset stLocal.returnstruct.message = "">
		<cfset stLocal.fuStatus = "">

		<cfswitch expression="#arguments.fuStatus#">
			<cfcase value="current">
				<cfset stLocal.fuStatus = "1,2">
			</cfcase>
		
			<cfcase value="active">
				<cfset stLocal.fuStatus = "1">
			</cfcase>
		
			<cfcase value="permanent">
				<cfset stLocal.fuStatus = "2">
			</cfcase>
		
			<cfcase value="archived">
				<cfset stLocal.fuStatus = "0">
			</cfcase>
		
			<cfcase value="exclusion">
				<cfset stLocal.fuStatus = "-1">
			</cfcase>
					
			<cfdefaultcase>
				<cfset stLocal.fuStatus = "-1,0,1,2">
			</cfdefaultcase>
		</cfswitch>
		
		<cftry>
			<!--- get friendly url based on the objectid --->
			<cfswitch expression="#application.dbtype#">
			<cfcase value="ora,oracle">					
				<cfquery datasource="#application.dsn#" name="stLocal.qList">
				SELECT	u.objectid, friendlyURL, refobjectid, queryString, u.datetimelastupdated, u.fuStatus
				FROM	#application.dbowner#farFu u, 
						#application.dbowner#refObjects r
				WHERE	r.objectid = u.refobjectid
						AND u.refobjectid = <cfqueryparam value="#arguments.objectid#" cfsqltype="cf_sql_varchar">
						AND u.fuStatus IN (#stLocal.fuStatus#)
				ORDER BY fuStatus DESC
				</cfquery>
			</cfcase>
			<cfdefaultcase>
				<cfquery datasource="#application.dsn#" name="stLocal.qList">
				SELECT	u.objectid, friendlyURL, refobjectid, queryString, u.datetimelastupdated, u.fuStatus
				FROM	#application.dbowner#farFu u inner join 
						#application.dbowner#refObjects r on r.objectid = u.refobjectid
				WHERE	refobjectid = <cfqueryparam value="#arguments.objectid#" cfsqltype="cf_sql_varchar">
					AND fuStatus IN (#stLocal.fuStatus#)
				ORDER BY fuStatus DESC
				</cfquery>
			</cfdefaultcase>
			</cfswitch>

			<cfset stLocal.returnstruct.queryObject = stLocal.qList>

			<cfcatch>
				<cfset stLocal.returnstruct.bSuccess = 0>
				<cfset stLocal.returnstruct.message = "#cfcatch.message# - #cfcatch.detail#">
			</cfcatch>
		</cftry>
		
		<cfreturn stLocal.returnstruct>
	</cffunction>
	
	<cffunction name="fInsert" access="public" returntype="struct" hint="returns a query of FU for a particular objectid" output="No">
		<cfargument name="stForm" required="yes" hint="friendly url struct" type="struct" />

		<cfset var stLocal = StructNew()>
		<cfset stLocal.returnstruct = StructNew()>
		<cfset stLocal.returnstruct.bSuccess = 1>
		<cfset stLocal.returnstruct.message = "">

		<cftry>
			<!--- check if that friendly url exists --->
			<!--- IS THIS JUST TOO FUNNY? --->
<!--- 			<cfset arguments.stForm.friendlyUrl = ReplaceNoCase(arguments.stForm.friendlyUrl,application.config.fusettings.urlpattern,"")>
			<cfset arguments.stForm.friendlyUrl = application.config.fusettings.urlpattern & arguments.stForm.friendlyUrl> --->

			<cfif left(arguments.stForm.friendlyURL,1) NEQ "/">
				<cfset arguments.stForm.friendlyURL = "/#arguments.stForm.friendlyURL#" />
			</cfif>
			
			<cfquery datasource="#application.dsn#" name="stLocal.qCheck">
			SELECT	objectid
			FROM	#application.dbowner#farFu
			WHERE	lower(friendlyURL) = <cfqueryparam value="#LCase(arguments.stForm.friendlyurl)#" cfsqltype="cf_sql_varchar">
				AND fuStatus != 0
			</cfquery>
			
			<cfif stLocal.qCheck.recordcount EQ 0>
				<cfset arguments.stForm.objectID = CreateUUID()>
				<cfset stResult = createData(stProperties="#arguments.stForm#") />
				
			
				<!--- add to app scope --->
				<cfif arguments.stForm.fuStatus GT 0>
					<cfset variables.stMappings[arguments.stForm.friendlyURL] = StructNew() />
					<cfset variables.stMappings[arguments.stForm.friendlyURL].refobjectid = arguments.stForm.refObjectID />
					<cfset variables.stMappings[arguments.stForm.friendlyURL].queryString = arguments.stForm.querystring />
					<cfset variables.stLookup[arguments.stForm.refObjectID] = arguments.stForm.friendlyURL />
				</cfif>
			<cfelse>
				<cfset stLocal.returnstruct.bSuccess = 0>
				<cfset stLocal.returnstruct.message = "Sorry the Friendly URL: #arguments.stForm.friendlyurl# is currently active.<br />">
			</cfif>

			<cfcatch>
				<cfset stLocal.returnstruct.bSuccess = 0>
				<cfset stLocal.returnstruct.message = "#cfcatch.message# - #cfcatch.detail#">
			</cfcatch>
		</cftry>
		
		<cfreturn stLocal.returnstruct>
	</cffunction>
	
	<cffunction name="fDelete" access="public" returntype="struct" hint="returns a query of FU for a particular objectid" output="No">
		<cfargument name="stForm" required="yes" hint="friendly url struct" type="struct" />

		<cfset var stLocal = StructNew()>
		<cfset stLocal.returnstruct = StructNew()>
		<cfset stLocal.returnstruct.bSuccess = 1>
		<cfset stLocal.returnstruct.message = "">

		<cftry>
			<cfset arguments.stForm.lDeleteObjectid = ListQualify(arguments.stForm.lDeleteObjectid,"'")>
			<cfquery datasource="#application.dsn#" name="stLocal.qList">
			SELECT	friendlyurl
			FROM	#application.dbowner#farFu
			WHERE	objectid IN (#preservesinglequotes(arguments.stForm.lDeleteObjectid)#)
			</cfquery>

			<cfquery datasource="#application.dsn#" name="stLocal.qDelete">
			DELETE
			FROM	#application.dbowner#farFu
			WHERE	objectid IN (#preservesinglequotes(arguments.stForm.lDeleteObjectid)#)
			</cfquery>
			
			<cfloop query="stLocal.qList">
				<!--- delete from app scope --->
				<cfset StructDelete(application.FU.mappings,stLocal.qList.friendlyurl)>
			</cfloop>

			<cfcatch>
				<cfset stLocal.returnstruct.bSuccess = 0>
				<cfset stLocal.returnstruct.message = "#cfcatch.message# - #cfcatch.detail#">
			</cfcatch>
		</cftry>
		
		<cfreturn stLocal.returnstruct>
	</cffunction>
		
</cfcomponent>