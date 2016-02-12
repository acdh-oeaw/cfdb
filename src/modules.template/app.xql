xquery version "3.0";

module namespace app="@app.uri@/templates";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace dc = "http://purl.org/dc/elements/1.1/";
declare namespace dcterms = "http://purl.org/dc/terms/";


import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="@app.uri@/config" at "config.xqm";
import module namespace tablet="@app.uri@/tablet" at "tablet.xqm";
import module namespace a="@app.uri@/annotations" at "annotations.xqm";
import module namespace search = "@app.uri@/search" at "search.xqm";
import module namespace cfdb = "@app.uri@/db" at "cfdb.xqm";
import module namespace archive="@app.uri@/archive" at "archive.xqm";

declare namespace cfdba = "@app.archive-format.ns@";

(:~
 : This is a sample templating function. It will be called by the templating module if
 : it encounters an HTML element with an attribute data-template="app:test" 
 : or class="app:test" (deprecated). The function has to take at least 2 default
 : parameters. Additional parameters will be mapped to matching request or session parameters.
 : 
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
declare function app:current-user($node as node(), $model as map(*)) {
    <span xmlns="http://www.w3.org/1999/xhtml">{
        if (xmldb:get-current-user() != 'guest')
        then (
            xmldb:get-current-user()||" ",
            <span>(<a href="?logout=true">logout</a>)</span>
        )
        else <a href="login.html">Log in</a>
    }</span>
};


declare function app:listGlyphs($node as node(), $model as map(*)) {
    let $glyphs := collection($config:data-root||"/tablets")//tei:g
    return 
    	<table class="table">
    		<thead>
    			<th>Standard Sign</th>
    			<th>Reading</th>
    			<th>Period</th>
    			<th>Text</th>
    			<th/>
    		</thead>
    		<tbody>{
	    		for $g in $glyphs
	    		let $type := $g/@type,
	    			$tei := root($g)/tei:TEI,
	    			$doc-id := $tei/@xml:id,
	    			$doc-title := $tei/tei:teiHeader/tei:fileDesc/tei:titleStmt/xs:string(tei:title),
	    			$period := $tei/tei:teiHeader[1]/tei:profileDesc[1]/tei:creation[1]/tei:origDate[1]/tei:date[1]/xs:string(@period)
	    		(:group by $period:)
	    		order by $period, $type, $doc-id
	    		return
	    		<tr>
	    			<td>{xs:string($type)}</td>
	    			<td>{$g/text()}</td>
	    			<td>{$period}</td>
	    			<td>{$doc-title}</td>
	    			<td><a href="glyph.html?glyph-id={$g/@xml:id}">show</a></td>
	    		</tr>
	    	}</tbody>
	    </table>
};

(:declare function app:showGlyph($node as node(), $model as map(*)) {
	<span>no glyph-id</span>
};:)

declare function app:showGlyph($node as node(), $model as map(*), $glyph-id as xs:string?, $filterExpr as xs:string?) {
	if ($glyph-id and $glyph-id != '')
	then
		let $g := collection($config:data-root||"/tablets")//tei:g[@xml:id = $glyph-id],
		    $tablet-id := root($g)/tei:TEI/@xml:id,
		    $src := root($g)//tei:graphic[@xml:id=substring-after($g/@facs,'#')]/@url,
		    $glyph := root($g)//tei:glyph[@xml:id = substring-after($g/@ana,'#')]
		return 
		<div xmlns="http://www.w3.org/1999/xhtml">
    		  <h2>{$g}</h2>
    		  <table class="table" id="glyphDetails">
    		      <tbody>
    		          <tr>
    		              <td>ID</td>
    		              <td>{$g/xs:string(@xml:id)}</td>
    		          </tr>
    		          <tr>
    		              <td>Context</td>
    		              <td>{$g/parent::tei:seg[@type='context']}</td>
    		          </tr>
    		          {for $charProp in $glyph/tei:charProp return
    		          <tr>
    		              <td>{$charProp/tei:localName}</td>
    		              <td>{$charProp/tei:value}</td>
    		          </tr>}
    		          <tr>
    		              <td></td>
    		              <td><img src="$app-root/data/tablets/{$tablet-id}/{$src}"/></td>
    		          </tr>
    		      </tbody>
    		  </table>
		</div>
	else ()
};

(:~ The function app:renderAttributes displays annotation data of the glyph $g:)
declare function app:renderAttributes($g as element(tei:g)) as element(span) {
    <span class="attributes" xmlns="http://www.w3.org/1999/xhtml">
        <span class="attribute">Glyph: {a:sign($g)}</span>
        <span class="attribute">Reading: {xs:string($g/text())}</span>
        <span class="attribute">Context: {xs:string($g/parent::tei:seg)}</span>
        <span class="attribute">
            <a href="editTablets.html?t={$g/root(.)//tei:title}">edit tablet</a>
        </span>
    </span>
};

(:~ The function app:signlistNav displays the navigation and filter controls for the sign list (used in index.html) :)
declare function app:signlistNav($node as node(), $model as map(), $s as xs:string*, $order as xs:string*, $groupby as xs:string*, $after as xs:integer*, $before as xs:integer*) {
let $groupby := subsequence($groupby, 1, 1)
let $current-signs := 
        if ($s != '')
        then $cfdb:stdSigns[tei:charName = $s]
        else map:get($cfdb:stdSign-by-position, 1)
let $pos := map:get($cfdb:stdSign-position-by-charname, $current-signs[1]/tei:charName),
    $next := map:get($cfdb:stdSign-by-position, $pos+1),
    $prev := map:get($cfdb:stdSign-by-position, xs:integer($pos)-1)
return
<div class="well" xmlns="http://www.w3.org/1999/xhtml" id="signlist-nav">
    <h4>Grouping / Navigation</h4>
    <div>
        <ul class="inline">
            <li><span class="label label-{if ($groupby='period') then 'info' else 'default'}"><a style="color:white;" href="?{if ($groupby = "period") then () else "groupby=period"}{string-join((for $ss in $s return '&amp;s='||$ss),'')}{if (exists($before)) then '&amp;before='||$before else ''}{if (exists($after)) then '&amp;after='||$after else ''}">Period</a></span></li>
            <li><span class="label label-{if ($groupby='city') then 'info' else 'default'}"><a style="color:white;" href="?{if ($groupby = "city") then () else "groupby=city"}{string-join((for $ss in $s return '&amp;s='||$ss),'')}{if (exists($before)) then '&amp;before='||$before else ''}{if (exists($after)) then '&amp;after='||$after else ''}">City</a></span></li>
            <li><span class="label label-{if ($groupby='scribe') then 'info' else 'default'}"><a style="color:white;" href="?{if ($groupby = "scribe") then () else "groupby=scribe"}{string-join((for $ss in $s return '&amp;s='||$ss),'')}{if (exists($before)) then '&amp;before='||$before else ''}{if (exists($after)) then '&amp;after='||$after else ''}">Scribe</a></span></li>
            <li><span class="label label-{if ($groupby='archive') then 'info' else 'default'}"><a style="color:white;" href="?{if ($groupby = "archive") then () else "groupby=archive"}{string-join((for $ss in $s return '&amp;s='||$ss),'')}{if (exists($before)) then '&amp;before='||$before else ''}{if (exists($after)) then '&amp;after='||$after else ''}">Archive</a></span></li>
        </ul>
    </div>
    <div class="pagination">
      <ul>
        {if (exists($prev)) then <li><a data-s="{$prev/tei:charName}" href="{concat('?groupby=',$groupby,'&amp;s=',$prev/tei:charName)}{if (exists($before)) then '&amp;before='||$before else ''}{if (exists($after)) then '&amp;after='||$after else ''}">« {$prev/tei:charName}</a></li> else ()}
        <li class="disabled"><a href="#">{if (count($current-signs) gt 5) then concat($current-signs[1], " &#8230; ", $current-signs[last()]) else string-join($current-signs, " ")}</a></li>
        {if (exists($next)) then <li><a data-s="{$next/tei:charName}" href="{concat('?groupby=',$groupby,'&amp;s=',$next/tei:charName)}{if (exists($before)) then '&amp;before='||$before else ''}{if (exists($after)) then '&amp;after='||$after else ''}">{$next/tei:charName} »</a></li> else ()}
      </ul>
    </div>
    <form method="get" id="signlist-nav-form"><!-- id is used in signlist.js, do not change -->
        <input type="hidden" name="groupby" value="{$groupby}"/>
        <div>
            <div class="control-group">
                <div id="slider-range">
                    <span id="slider-range-min"></span>
                    <span id="slider-range-max"></span>
                </div>
                <p>
                    <span class="label label-info{if($after) then '' else ' hidden'}" id="after-display"><span class="content"></span><a class="removeDateFilter" data-filter="after" title="remove filter" href="#"><i class="fa fa-times">&#160;</i></a></span>
                    <span class="label label-info{if($before) then '' else ' hidden'}" id="before-display"><span class="content"></span><a class="removeDateFilter" data-filter="before" title="remove filter" href="#"><i class="fa fa-times">&#160;</i></a></span>
                </p>
            </div>
            <input id="before-input" type="hidden" name="before" value="{$before}"/>
            <input id="after-input" type="hidden" name="after" value="{$after}"/>
            <select name="s" multiple="" size="30">{
                for $o in $cfdb:stdSigns
                let $glyphs := collection($config:tablets-root)//tei:g[@type = $o/tei:charName],
                    $no := count($glyphs)
                return <option value="{$o/tei:charName}">{(
                    if ($o/tei:charName = $current-signs/tei:charName) then attribute selected {} else (), 
                    $o/@n||" "||$o/tei:charName||" ("||$no||")"
                )}</option>
            }</select>
            <!--<input type="submit" value="send"/>-->
        </div>
    </form>
</div>
};

declare
%templates:default("order","date")
function app:signlist($node as node(), $model as map(), $s as xs:string*, $order as xs:string*, $groupby as xs:string*, $after as xs:integer*, $before as xs:integer*) {
    let $groupby := subsequence($groupby,1,1),
        $after := subsequence($after[exists(.)], 1, 1),
        $after := if ($after lt 0) then $after * -1 else $after,
        $before := subsequence($before[exists(.)], 1, 1),
        $before := if ($before lt 0) then $before * -1 else $before
    let $stdsigns := $cfdb:stdSigns
    let $current-url := concat(
                            "?",
                            string-join(for $si in $s return concat('s=',$si),'&amp;s=')
                        )
    return
        for $stdsign in $stdsigns[if (exists($s)) then tei:charName = $s else 1]
        let $glyphs := collection($config:tablets-root)//tei:g[@type = $stdsign/tei:charName]
        let $no := count($glyphs)
        order by $stdsign/@n
        return 
            <div xmlns="http://www.w3.org/1999/xhtml" class="row-fluid">
                <div class="span3">
                    <h3>{$stdsign/tei:charName}<br/>
                    {$stdsign/xs:string(@n)}</h3>
                    {if (not($stdsign/tei:figure/tei:graphic/@url = ('img','')))
                    then <img src="$app-root/data/etc/stdSigns/{$stdsign/tei:figure/tei:graphic/@url}"/>
                    else ()}
                    <p>{$no} occurence{if ($no = 1) then () else 's'} in corpus</p>
                </div>
                <div class="span9">
                {for $group in $glyphs 
                let $creation := $group/root()//tei:creation,
                    $date := $creation/tei:origDate/tei:date,
                    $period := $date[@period]/@period,
                    $city := $creation/tei:origPlace/tei:placeName
                let $msIdentifier := $group/root()//tei:msIdentifier,
                    $archive := $msIdentifier/tei:collection[@type="archive"]
                let $sourceDesc := $group/root()//tei:sourceDesc,
                    $scribe := $sourceDesc//tei:persName[@role = "scribe"]/text()
                let $groupexpr := switch ($groupby)
                            case "date" return $date[@calendar = '#gregorian']/replace(.,'^~','') 
                            case "period" return $period
                            case "city" return $city
                            case "scribe" return $scribe
                            case "archive" return $archive
                            default return true() 
                let $dateBefore := ($date[@calendar = "#gregorian"], $date[@calendar = "#gregorian"]/@notAfter)[. != ""][1]/xs:integer(if(contains(.,'~')) then replace(.,'~','') else .),
                    $dateAfter := ($date[@calendar = "#gregorian"], $date[@calendar = "#gregorian"]/@notBefore)[. != ""][1]/xs:integer(if(contains(.,'~')) then replace(.,'~','') else .)
                let $dateFilter := count(($dateBefore,$dateAfter)) gt 0 and not(some $d in ($dateBefore gt $before, $dateAfter lt $after) satisfies exists($d) and $d = false())
                where 
                    if ($before or $after) 
                    then $dateFilter = true() 
                    else true()
                group by $groupexpr
                return      
                    <div>
                        <h4>{if (normalize-space($groupby) = "") then "All Occurences" else (xs:string($groupexpr),"[no value]")[.!=''][1]}&#160;<small>{count($group)}  occurences</small></h4> 
                        <ul class="thumbnails">{
                            for $g in $group
                            let $tablet-id := $g/ancestor::tei:TEI/@xml:id,
                                $glyph-id := $g/@xml:id,
                                $facspath := root($g)//tei:graphic[@xml:id = substring-after($g/@facs,'#')]/@url,
                                $facsurl :=  concat('$tablets-root/',$tablet-id,'/',$facspath)
                            let $msIdentifier := root($g)//tei:msIdentifier,
                                $archive := $msIdentifier/tei:collection[@type="archive"],
                                $museumNo := $msIdentifier/tei:altIdentifier[@type="museumNumber"]
                            let $creation := $g/root()//tei:creation,
                                $date := $creation/tei:origDate/tei:date,
                                $period := $date[@period]/@period, 
                                $city := $creation/tei:origPlace/tei:placeName,
                                $context := $g/parent::tei:seg
                            let $dateBefore := ($date[@calendar = "#gregorian"], $date[@calendar = "#gregorian"]/@notAfter)[. != ""][1]/xs:integer(if(contains(.,'~')) then replace(.,'~','') else .),
                                $dateAfter := ($date[@calendar = "#gregorian"], $date[@calendar = "#gregorian"]/@notBefore)[. != ""][1]/xs:integer(if(contains(.,'~')) then replace(.,'~','') else .)
                            let $dateFilter := count(($dateBefore,$dateAfter)) gt 0 and not(some $d in ($dateBefore gt $before, $dateAfter lt $after) satisfies exists($d) and $d = false())
                            let $orderexpr := switch ($order)
                                case "date" return $date[@calendar = '#gregorian']/replace(.,'^~','') 
                                case "period" return $date[@calendar = '#gregorian']/replace(.,'^~','')
                                case "city" return $city
                                default return true()
                            order by $orderexpr  
                            return 
                            <li class="span2 gThumbnail">
                                <a href="#" class="thumbnail">
                                    <img src="{$facsurl}"/>
                                    <span class="attributes" style="width:auto; min-width: 250px;">
                                        <span class="attribute"><span class="attribute-label">Text:</span><span class="attribute-value">{$museumNo}</span></span>
                                        <span class="attribute"><span class="attribute-label">Archive:</span><span class="attribute-value">{$archive}</span></span>
                                        <span class="attribute"><span class="attribute-label">Reading:</span><span class="attribute-value">{$g}</span></span>
                                        <span class="attribute"><span class="attribute-label">Context:</span><span class="attribute-value">{$context}</span></span>
                                        <span class="attribute"><span class="attribute-label">City:</span><span class="attribute-value">{$city}</span></span>
                                        <span class="attribute"><span class="attribute-label">Period:</span><span class="attribute-value">{$date[@period]/@period}</span></span>
                                        <span class="attribute"><span class="attribute-label">Date:</span><span class="attribute-value">{if ($date[@calendar="#gregorian"] != '') then $date[@calendar="#gregorian"] else concat($date[@calendar="#gregorian"]/xs:string(@notBefore), ' / ', $date[@calendar="#gregorian"]/@notAfter)}</span></span>
                                        <span class="attribute"><span class="attribute-label">Date (Babylonian):</span><span class="attribute-value">{$date[@calendar = '#babylonian']}</span></span>
                                    </span>
                                </a>
                            </li>
                        }</ul>
                    </div>
                }
                </div>
            </div>
};

declare function app:archivelist($node, $model) {
    let $snapshots := archive:list()
    return
    <div xmlns="http://www.w3.org/1999/xhtml">
        <table class="table" id="snapshots">
            <thead>
                <th>Name</th>
                <th>Version</th>
                <th>Issued</th>
                <th>Size</th>
                <th>Metadata</th>
                {if (xmldb:get-current-user() = $config:editors) then <th>Actions</th> else ()}
            </thead>
            <tbody>{
                if (not($snapshots))
                then <tr xmlns="http://www.w3.org/1999/xhtml" id="no-snapshots-placeholder"><td style="text-align: center;" colspan="6"><i>No snapshots created so far.</i></td></tr> 
                else 
                    for $md in $snapshots
                    let $md-extra := archive:get-extra-metadata($md),
                        $identifier := $md-extra/dc:identifier/xs:string(.), 
                        $isDeployed := config:get("deployed-snapshot") = $md-extra/dc:identifier
                    let $zip-filename := $md-extra//cfdba:zip-filename,
                        $zip-available := $md-extra//cfdba:zip-available eq "true",
                        $md-filename := $md-extra//cfdba:md-filename,
                        $date-formatted := $md-extra//cfdba:date-formatted,
                        $size-formatted := $md-extra//cfdba:size-formatted,
                        $version := $md-extra/xs:integer(@version)
                    order by $version
                    return
                        <tr xmlns="http://www.w3.org/1999/xhtml" data-snapshot-id="{$identifier}" data-snapshot-title="{$md-extra/dc:title}">
                            <td>{
                                if ($zip-available) 
                                then (
                                    <a href="archive/{$zip-filename}">{$md-extra/dc:title}</a>,
                                    if ($config:isPublicInstance)
                                    then
                                        let $is-unpacked := xmldb:collection-available($archive:repo-path||"/"||$identifier),
                                            $deployment-status := archive:check-deployment-sanity($identifier),
                                            $deployment-status-ok := $deployment-status("status") eq "ok"
                                        return
                                            if (xmldb:get-current-user() = $config:editors) 
                                            then 
                                                if ($isDeployed and $deployment-status-ok) then <i class="fa fa-check-square deployed" title="This snapshot is deployed."></i>
                                                else if ($deployment-status-ok) then <a href="#" title="This snapshot is unpacked but not deployed. Click here to remove unpacked files. Click on 'deploy' symbol on the right to deploy." data-action="remove-snapshot-artefacts"><i class="fa fa-check-square undeployed"></i><i class="fa fa-trash"></i></a>
                                                else if ($is-unpacked and not($deployment-status-ok)) then <i class="fa fa-exclamation-triangle" title="There is a problem with the current deployment. {$deployment-status("msg")}"></i>
                                                else ()
                                            else
                                                if ($isDeployed and $deployment-status-ok) 
                                                then <i class="fa fa-check-square deployed" title="This snapshot is deployed."></i>
                                                else ()
                                    else ()
                                )
                                else "file "||$zip-filename||" is missing (orphaned metadata entry)"
                            }</td>
                            <td>{$version}</td>
                            <td>{$date-formatted}</td>
                            <td>{$size-formatted}</td>
                            <td><a href="archive/{$md-filename}" class="archive-md-link"><span class="label">show</span>{transform:transform($md-extra, doc($config:app-root||"/dc2html.xsl"), ())}</a></td>
                            {if (xmldb:get-current-user() = $config:editors) then 
                                <td>
                                    <a href="#" data-action="removeSnapshot" title="Remove this snapshot"><i class="fa fa-times"></i></a>
                                    {if (not($isDeployed) and $config:isPublicInstance)
                                    then <a href="#" data-action="deploySnapshot" title="Deploy this snapshot"><i class="fa fa-upload"></i></a>
                                    else ()}
                                </td> 
                             else ()}
                        </tr>
            }</tbody>
        </table>
    </div>
};

(: MENUS :)
declare function app:menu-edit($node, $model) {
    if ($config:isPublicInstance)
    then ()
    else
        <li class="dropdown" id="edit" xmlns="http://www.w3.org/1999/xhtml">
            <a href="#" class="dropdown-toggle" data-toggle="dropdown">Data Curation</a>
            <ul class="dropdown-menu">
                <li>
                    <a href="editTablets.html">Tablets</a>
                </li>
                <li>
                    <a href="editStdSigns.html">Standard Signs</a>
                </li>
                <li>
                    <a href="editArchives.html">Regions, Archives and Dossiers</a>
                </li>
            </ul>
        </li>
};

declare function app:menu-administration($node, $model) {
    if (xmldb:get-current-user() = $config:editors)
    then
        <li class="dropdown" id="administration">
            <a href="#" class="dropdown-toggle" data-toggle="dropdown">Administration</a>
                <ul class="dropdown-menu">
                    <li>
                        <a href="stats.html"><i class="fa fa-area-chart"/>&#160;Statistics</a>
                    </li>
                    <li>
                        <a href="administration.html"><i class="fa fa-wrench"/>&#160;General Configuration</a>
                    </li>
                </ul>
        </li>
    else ()
};

declare function app:input-create-snapshot($node, $model) {
    if (xmldb:get-current-user() = $config:editors and not($config:isPublicInstance))
    then (
        <div class="well" xmlns="http://www.w3.org/1999/xhtml">
            <h4>Create new snapshot</h4>
            <p>Archive metadata (publisher, public URL, license etc) can be entered in the <a href="administration.html">General&#160;Configuration</a> page.</p>
            <form id="input-create-snapshot" action="">
                <label for="version">Version</label>
                <input id="version" name="version" value="{max(archive:list()/xs:integer(@version)) + 1}" type="number" min="{max(archive:list()/xs:integer(@version)) + 1}"/>
                <button><i class="fa fa-file-archive-o"></i>&#160;create</button>
                <span class="spinner">&#160;<i class="fa fa-spinner fa-spin"/></span>
            </form>
        </div>)
    else ()
};

(:~ This function creates an upload field to upload corpus snapshots and deploy them on a public instance. 
 : 
 :)
declare function app:input-upload-snapshot($node, $model) {
    if (xmldb:get-current-user() = $config:editors and $config:isPublicInstance)
    then (
        <p xmlns="http://www.w3.org/1999/xhtml">Snapshots can be deployed by clicking on&#160;<i class="fa fa-upload"/>. The snapshot currently deployed is marked by the icon&#160;<i class="fa fa-check-square deployed" title="This snapshot is deployed."/>. The unzipped contents of the archive are kept in the system after undeploying. This is indicated by&#160;<i class="fa fa-check-square undeployed"/>. To re-deploy a snaphot, click on the <i>Deploy</i> icon again. Snapshot artefacts can be removed from the system by clicking on the&#160;<i class="fa fa-check-square undeployed"/> icon.</p>,    
        <div class="well" xmlns="http://www.w3.org/1999/xhtml">
            <h4>Upload snapshot</h4>
            <div id="filelist"></div>
            <form id="input-upload-snapshot" method="POST">
                <input id="snapshot" name="snapshot" type="file"/>
                <button type="submit" id="uploadarchive">Upload</button>
                <span class="spinner">&#160;<i class="fa fa-spinner fa-spin"/></span>
            </form>
        </div>
        )
    else ()
};

(:~ This function creates an upload field to upload corpus snapshots and deploy them on a public instance. 
 : 
 :)
declare function app:form-configuration($node, $model) {
    if (xmldb:get-current-user() = $config:editors)
    then
        <div xmlns="http://www.w3.org/1999/xhtml">
            <form id="form-configuration" method="PUT" class="form-horizontal">
                <div class="tabbable">
                    <ul class="nav nav-tabs">
                        <li class="active">
                            <a href="#tab1" data-toggle="tab">Database Settings</a>
                            
                        </li>
                        <li>
                            <a href="#tab2" data-toggle="tab">Archive Settings</a>
                        </li>
                    </ul>
                    <div class="tab-content">
                        <div class="tab-pane active" id="tab1">
                            <h4>Database Settings</h4>
                            <label for="operation-mode">Operation mode</label>
                            <select id="operation-mode" name="operation-mode">
                                <option value="public">{if (config:get("operation-mode") = "public") then attribute selected {"selected"} else ()}Public Mode</option>
                                <option value="curation">{if (config:get("operation-mode") = "curation") then attribute selected {"selected"} else ()}Curation </option>
                            </select>
                        </div>
                        <div class="tab-pane" id="tab2">
                            <h4>Archive Settings</h4>    
                            <label for="publisher">Publisher</label>
                            <input id="publisher" type="text" class="form-control" name="publisher" value="{config:get("publisher")}"/>
                            <label for="license">License</label>
                            <input id="license" type="text" class="form-control" name="license" value="{config:get("license")}"/>
                            <label for="public-url">Public URL</label>
                            <input id="public-url" type="text" class="form-control" name="public-url" value="{config:get("public-url")}"/>
                        </div>
                    </div>
                    <button type="submit">Save settings</button>
                    <button type="resset">Reset</button>
                </div>
            </form>
        </div>
    else ()
};

declare function app:version($node, $model) {
    if ($config:isPublicInstance)
    then 
        let $snapshot-id := config:get("deployed-snapshot"),
            $md := archive:get($snapshot-id)
        return <span xmlns="http://www.w3.org/1999/xhtml">Corpus version {$md/xs:string(@version)} ({$md//dc:identifier/xs:string(.)})</span>
    else ()
};