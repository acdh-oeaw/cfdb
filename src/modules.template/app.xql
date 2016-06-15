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

declare function app:renderTablet($node, $model, $id as xs:string) {
    let $tablet := tablet:get($id),
        $xsl := doc($config:tablet2html)
    return <div xmlns="http://www.w3.org/1999/xhtml" id="tablet">{transform:transform($tablet, $xsl, <parameters><param name="taxonomies.path" value="{$config:tablets-root}/../etc/taxonomies.xml"/><param name="makeAnnotateLink" value="false"/></parameters>)}</div>
};

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
    let $props := a:get-attributes($g, ())
    return
        <span class="attributes" xmlns="http://www.w3.org/1999/xhtml">
            <span class="attribute">Glyph: {$props/sign}</span>
            <span class="attribute">Reading: {$props/reading}</span>
            <span class="attribute">Context: {$props/context}</span>
            <span class="attribute">
                <a href="editTablets.html?t={$g/root(.)//tei:title}">edit tablet</a>
            </span>
        </span>
};

(:~ The function app:signlistNav displays the navigation and filter controls for the sign list (used in index.html) :)
declare function app:signlistNav($node as node(), $model as map(), $s as xs:string*, $order as xs:string*, $groupby as xs:string*, $after as xs:integer*, $before as xs:integer*) {
let $groupby := $groupby[. = $config:valid-grouping-keys]
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
            <li><span class="label label-{if ($groupby='period') then 'info' else 'default'}"><a style="color:white;" href="?{if ($groupby = 'period') then '' else 'groupby=period&amp;'}{string-join((for $g in $groupby[. != "period"] return 'groupby='||$g),'&amp;')}{string-join((for $ss in $s return '&amp;s='||$ss),'')}{if (exists($before)) then '&amp;before='||$before else ''}{if (exists($after)) then '&amp;after='||$after else ''}">Period</a></span></li>
            <li><span class="label label-{if ($groupby='region') then 'info' else 'default'}"><a style="color:white;" href="?{if ($groupby = 'region') then '' else 'groupby=region&amp;'}{string-join((for $g in $groupby[. != "region"] return 'groupby='||$g),'&amp;')}{string-join((for $ss in $s return '&amp;s='||$ss),'')}{if (exists($before)) then '&amp;before='||$before else ''}{if (exists($after)) then '&amp;after='||$after else ''}">Region</a></span></li>
            <li><span class="label label-{if ($groupby='scribe') then 'info' else 'default'}"><a style="color:white;" href="?{if ($groupby = 'scribe') then '' else 'groupby=scribe&amp;'}{string-join((for $g in $groupby[. != "scribe"] return 'groupby='||$g),'&amp;')}{string-join((for $ss in $s return '&amp;s='||$ss),'')}{if (exists($before)) then '&amp;before='||$before else ''}{if (exists($after)) then '&amp;after='||$after else ''}">Scribe</a></span></li>
            <li><span class="label label-{if ($groupby='archive') then 'info' else 'default'}"><a style="color:white;" href="?{if ($groupby = 'archive') then '' else 'groupby=archive&amp;'}{string-join((for $g in $groupby[. != "archive"] return 'groupby='||$g),'&amp;')}{string-join((for $ss in $s return '&amp;s='||$ss),'')}{if (exists($before)) then '&amp;before='||$before else ''}{if (exists($after)) then '&amp;after='||$after else ''}">Archive</a></span></li>
        </ul>
    </div>
    <div class="pagination">
      <ul>
        {if (exists($prev)) then <li><a data-s="{$prev/tei:charName}" href="{concat('?',string-join((for $g in $groupby return concat("groupby=", $g)),'&amp;='),'&amp;s=',$prev/tei:charName)}{if (exists($before)) then '&amp;before='||$before else ''}{if (exists($after)) then '&amp;after='||$after else ''}">« {$prev/tei:charName}</a></li> else ()}
        <li class="disabled"><a href="#">{if (count($current-signs) gt 5) then concat($current-signs[1]/tei:charName, " &#8230; ", $current-signs[last()]/tei:charName) else string-join($current-signs/tei:charName, " ")}</a></li>
        {if (exists($next)) then <li><a data-s="{$next/tei:charName}" href="{concat('?',string-join((for $g in $groupby return concat("groupby=", $g)),'&amp;='),'&amp;s=',$next/tei:charName)}{if (exists($before)) then '&amp;before='||$before else ''}{if (exists($after)) then '&amp;after='||$after else ''}">{$next/tei:charName} »</a></li> else ()}
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
%templates:default("order", "date")
%templates:default("s", "BA")
function app:signlist($node as node(), $model as map(), $s as xs:string*, $order as xs:string*, $groupby as xs:string*, $after as xs:integer*, $before as xs:integer*, $collapse-signs) {
    let $groupby := $groupby[. = $config:valid-grouping-keys]
    let $after := subsequence($after[exists(.)], 1, 1),
        $after := if ($after lt 0) then $after * -1 else $after,
        $before := subsequence($before[exists(.)], 1, 1),
        $before := if ($before lt 0) then $before * -1 else $before
    let $stdSigns := $cfdb:stdSigns
    let $current-url := concat(
                            "?",
                            string-join(for $si in $s return concat('s=',$si),'&amp;s=')
                        )
    let $annotations := if ($collapse-signs = "true") then cfdb:list-annotations("sign-type", $s, $after, $before, $groupby, true()) else ()
    return
        for $ss at $spos in $s 
            let $annotations := if ($collapse-signs = "true") then $annotations else cfdb:list-annotations("sign-type", $ss, $after, $before, $groupby, false())
            let $stdSign := $stdSigns[tei:charName = $ss],
                $signNumber := xs:integer(replace($stdSign/@n, '\P{N}', '')),
                $annotations-of-sign-type := $annotations//annotation[sign = $ss],
                $annotations-groups := $annotations/group
            order by $signNumber
            return 
                <div xmlns="http://www.w3.org/1999/xhtml" class="row-fluid">
                    <div class="span3">
                        <h3>{$stdSign/tei:charName}<br/>{$stdSign/xs:string(@n)}</h3>
                        {if (not($stdSign/tei:figure/tei:graphic/@url = ('img','')))
                        then <img src="$app-root/data/etc/stdSigns/{$stdSign/tei:figure/tei:graphic/@url}"/>
                        else ()}
                        <!--<p>{$no} occurence{if ($no = 1) then () else 's'} in corpus</p>-->
                    </div>
                    <div class="span9">{
                        if ($collapse-signs  = "true" and $spos gt 1) then () else 
                        if (not(exists($groupby[. != ""]))) 
                        then
                            (<h4>All Occurences <small>{count($annotations-of-sign-type)} forms</small></h4>,
                             <ul class="thumbnails" xmlns="http://www.w3.org/1999/xhtml">{ 
                                for $a in $annotations-of-sign-type 
                                return app:signlistEntry($a) 
                            }</ul>)
                        else
                            for $g in $annotations-groups
                            let $as := $g/*
                            where count($as) ge 1
                            return 
                                <div xmlns="http://www.w3.org/1999/xhtml">
                                    <h4>{xs:string($g/@grouping-value)}&#160;<small>{count($as)} occurences</small></h4>
                                    <ul class="thumbnails" xmlns="http://www.w3.org/1999/xhtml">{for $a in $as return app:signlistEntry($a)}</ul>
                                </div>
                    }</div>
                </div>
};

declare function app:signlistEntry($a as element(annotation)) {
    let $tablet-id := $a//tablet,
        $facsurl := $a//img,
        $archive := $a//archive,
        $reading := $a//reading,
        $context := $a//context,
        $place := $a//place,
        $date-babylonian := $a//date-babylonian,
        $period := $a//period,
        $date := 
            if ($a//date-verbatim != '') then $a//date-verbatim else
            if ($a//date-min = '' and $a//date-max = '') then '[n/a]' else
            if ($a//date-min eq $a//date-max) then $a//date-min 
            else concat($a//date-min, "/", $a//date-max)
    return
    
    <li class="span2 gThumbnail" xmlns="http://www.w3.org/1999/xhtml">
        <a href="tablet.html?id={$tablet-id}" class="thumbnail">
            <img src="{$facsurl}"/>
            <span class="attributes" style="width:auto; min-width: 250px;">
                <!--<span class="attribute"><span class="attribute-label">Text:</span><span class="attribute-value">{$museumNo}</span></span>-->
                <span class="attribute"><span class="attribute-label">Archive:</span><span class="attribute-value">{$archive}</span></span>
                <span class="attribute"><span class="attribute-label">Reading:</span><span class="attribute-value">{$reading}</span></span>
                <span class="attribute"><span class="attribute-label">Context:</span><span class="attribute-value">{$context}</span></span>
                <span class="attribute"><span class="attribute-label">Region:</span><span class="attribute-value">{$place}</span></span>
                <span class="attribute"><span class="attribute-label">Period:</span><span class="attribute-value">{$period}</span></span>
                <span class="attribute"><span class="attribute-label">Date:</span><span class="attribute-value">{$date}</span></span>
                <span class="attribute"><span class="attribute-label">Date (Babylonian):</span><span class="attribute-value">{$date-babylonian}</span></span>
            </span>
        </a>
    </li>
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
                        <a href="charts.html"><i class="fa fa fa-bar-chart"/>&#160;Charts</a>
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
            <div class="progress">
                <div class="bar" role="progressbar" aria-valuenow="2" aria-valuemin="0" aria-valuemax="100" style="min-width: 2em; width: 2%;"></div>
            </div>
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