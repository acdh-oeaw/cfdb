xquery version "3.0";

module namespace app="@app.uri@/templates";

declare namespace tei = "http://www.tei-c.org/ns/1.0";


import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="@app.uri@/config" at "config.xqm";
import module namespace tablet="@app.uri@/tablet" at "tablet.xqm";
import module namespace a="@app.uri@/annotations" at "annotations.xqm";
import module namespace search = "@app.uri@/search" at "search.xqm";
import module namespace cfdb = "@app.uri@/db" at "cfdb.xqm";

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
        else 'not logged in'
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
        <li class="disabled"><a href="#">{string-join($current-signs, " ")}</a></li>
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
                                $facsurl :=  concat('$app-root/data/tablets/',$tablet-id,'/',$facspath)
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

declare %templates:wrap function app:tabletsAsJson($node as node(), $model as map()) {
let $data := cfdb:tabletsAsJSON()
return 
    "var cfdb = cfdb || {};
cfdb.tablets = "||$data||";"        
};

(:declare %templates:wrap function app:creds($node as node(), $model as map()) {
"var cfdb = cfdb || {};
cfdb.user = '"||session:get-attribute("user")||"';
cfdb.password = '"||session:get-attribute("password")||"';"
};:)