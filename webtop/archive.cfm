<cfsetting enablecfoutputonly="true" />
<!--- 
|| LEGAL ||
$Copyright: Daemon Pty Limited 1995-2003, http://www.daemon.com.au $
$License: Released Under the "Common Public License 1.0", http://www.opensource.org/licenses/cpl.php$ 

|| VERSION CONTROL ||
$Header: /cvs/farcry/core/webtop/archive.cfm,v 1.2 2005/10/06 06:18:35 daniela Exp $
$Author: daniela $
$Date: 2005/10/06 06:18:35 $
$Name: milestone_3-0-1 $
$Revision: 1.2 $

|| DESCRIPTION || 
$Description: shows archived objects $


|| DEVELOPER ||
$Developer: Brendan Sisson (brendan@daemon.com.au)$

|| ATTRIBUTES ||
$in: $
$out:$
--->

<cfprocessingDirective pageencoding="utf-8">

<cfparam name="finish_url" default="#cgi.http_referer#" />

<!--- set up page header --->
<cfimport taglib="/farcry/core/tags/admin/" prefix="admin">
<cfimport taglib="/farcry/core/tags/security/" prefix="sec" />

<admin:header writingDir="#session.writingDir#" userLanguage="#session.userLanguage#">

<sec:CheckPermission error="true" permission="ObjectArchiveTab">
	<cfoutput>	<h3>#application.rb.getResource("archive")#</h3></cfoutput>

	<!--- check if rollback is required --->
	<cfif structKeyExists(url, "archiveid")>
		
		<!--- get type --->
		<cfset oFourq = createObject("component","farcry.core.packages.fourq.fourq") />
		<cfset typename = oFourq.findType(url.objectid) />
		<cfset oType = createObject("component",application.types[typename].typepath) />
		
		<!--- rollback arvhice --->
		<cfset stRollback = oType.archiveRollback(objectID="#url.objectid#",archiveId="#url.archiveid#",typename=typename) />
		<cfoutput>
		<script type="text/javascript">
			if(parent['sidebar'].frames['sideTree']){
				parent['sidebar'].frames['sideTree'].location= parent['sidebar'].frames['sideTree'].location;
			}
			location.href = "#finish_url#";
		</script></cfoutput>
		<cfabort>
	</cfif>
	
	<!--- get archives --->
	<cfinvoke component="#application.packagepath#.farcry.versioning" method="getArchives" returnvariable="getArchivesRet">
		<cfinvokeargument name="objectID" value="#url.objectid#" />
	</cfinvoke>

	<cfoutput>
	<table cellspacing="0"></cfoutput>
	<cfif getArchivesRet.recordcount gt 0>
		<!--- setup table --->
		<cfoutput>
		<tr>
			<th>#application.rb.getResource("Date")#</th>
			<th>#application.rb.getResource("Label")#</th>
			<th>#application.rb.getResource("User")#</th>
			<!--- <th>&nbsp;</th> --->
			<th>&nbsp;</th>
			<th>&nbsp;</th>
		</tr>
		</cfoutput>
		<!--- loop over archives --->
		<cfloop query="getArchivesRet">
		<cfoutput>
		<tr>
			<td>
			#application.thisCalendar.i18nDateFormat(DATETIMELASTUPDATED,session.dmProfile.locale,application.longF)# 
			#application.thisCalendar.i18nTimeFormat(DATETIMELASTUPDATED,session.dmProfile.locale,application.shortF)#
			</td>
			<td>#label#</td>
			<td>#lastupdatedby#</td>
			<!--- <td><a href="edittabArchiveDetail.cfm?archiveid=#objectid#">#application.rb.getResource("moreDetail")#</a></td> --->
			<td><a href="#application.url.conjurer#?archiveid=#objectid#" target="_blank">#application.rb.getResource("archivePreview")#</a></td>
			<td>
				<a href="archive.cfm?objectid=#url.objectid#&amp;archiveid=#objectid#&amp;finish_url=#cgi.http_referer#" onclick="return confirm('Are you sure you want to rollback to this version?')">Rollback</a></cfoutput>
				<!--- check if archive has been rolled back successfully --->
				<cfif isdefined("url.archiveid") and stRollback.result and url.archiveId eq objectid>
					<cfoutput>
					<span style="color:Red">#application.rb.getResource("rolledBackOK")#</span></cfoutput>
				</cfif>
				<cfoutput>
			</td>
		</tr></cfoutput>
		</cfloop>
	<cfelse>
		<cfoutput>
		<tr>
			<td colspan="6">#application.rb.getResource("noArchiveRecorded")#</td>
		</tr></cfoutput>
	</cfif>
	<cfoutput>
	</table>
	<a href="#finish_url#">[Cancel]</a></cfoutput>
</sec:CheckPermission>

<!--- setup footer --->
<admin:footer>
<cfsetting enablecfoutputonly="false" />