xquery version "3.0";

module namespace app="@app.uri@/templates";

declare namespace tei = "http://www.tei-c.org/ns/1.0";


import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="@app.uri@/config" at "config.xqm";
import module namespace tablet="@app.uri@/tablet" at "tablet.xqm";
import module namespace a="@app.uri@/annotations" at "annotations.xqm";
import module namespace search = "@app.uri@/search" at "search.xqm";

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

declare function app:options-signs($node as node(), $model as map(*), $sign as xs:string*) {
    let $signs := doc($config:data-root||"/etc/stdSigns/stdSigns.xml")//tei:char
    let $output :=
        for $s in $signs
        let $name := normalize-space($s/tei:charName)
        order by $name
        return 
            <option xmlns="http://www.w3.org/1999/xhtml" value="{$name}">{(
                if ($name = $sign) 
                then attribute selected {"selected"}
                else (),
                $name
            )}</option>
    return $output        
};

declare function app:fieldset($node as node(), $model as map(*), $name as xs:string, $reading as xs:string*, $context as xs:string*) {
    let $values := 
        try { util:eval("$"||$name) } 
        catch * { () }
    let $vv := if (exists($values)) then $values else ""
    return
        <div xmlns="http://www.w3.org/1999/xhtml">{
            for $v in $vv return 
            <fieldset name="{$name}">
                <label for="{$name}">{upper-case(substring($name,1,1))||substring($name,2)}</label>
                <input name="{$name}" value="{$v}"/>
                <a href="#" class="addInput">
                    <span class="icon-plus-sign"/>
                </a>
                <a href="#" class="rmInput">
                    {if (count($vv) = 1) then attribute style {"display: none;"} else ()}
                    <span class="icon-minus-sign"/>
                </a>
            </fieldset>
        }</div>
};

declare 
    %templates:default("maxResults", 100)
    %templates:default("fromResult", 1)
    %templates:default("exact", "false")
function app:search($node as node(), $model as map(*), $reading as xs:string*, $sign as xs:string*, $context as xs:string*, $exact as xs:boolean, $dateMin as xs:string*, $dateMax as xs:string*, $maxResults as xs:integer?, $fromResult as xs:integer?) {
    let $data := collection($config:tablets-root)//tei:g
    (: we have to manually fetch some request parameters since the number of parameters provided by the templating framework is limited :)
    let $period := request:get-parameter("period", ""),
        $date-babylonian := request:get-parameter("date-babylonian", ""),
        $date-gregorian := request:get-parameter("date-gregorian", ""),
        $region := request:get-parameter("region", ""),
        $archive := request:get-parameter("archive", ""),
        $dossier := request:get-parameter("dosser", ""),
        (: the special request parameter "facets" indicates which search parameters (comma separated) are to be displayed as active filters in the facets column :)
        $facets := if (request:get-parameter("facets", "") != "") then tokenize(request:get-parameter("facets", ""),'\s*,\s*') else ()
        
    (: we create a map that holds all relevant request parameters to be sent to the db search function :)
    let $parts := (
        if ($reading != "") then map:entry("reading", distinct-values($reading)) else (),
        if ($context != "") then map:entry("context", distinct-values($context)) else (),
        if ($sign != "") then map:entry("sign", distinct-values($sign)) else (),
        if ($period != "") then map:entry("period", distinct-values($period)) else (),
        if ($archive != "") then map:entry("archive", distinct-values($archive)) else (),
        if ($dossier != "") then map:entry("dossier", distinct-values($dossier)) else (),
        if ($region != "") then map:entry("region", distinct-values($region)) else (),
        if ($date-babylonian != "") then map:entry("date-babylonian", distinct-values($date-babylonian)) else (),
        if ($date-gregorian != "") then map:entry("date-gregorian", distinct-values($date-gregorian)) else (),
        if ($dateMin != "") then map:entry("dateMin", distinct-values($dateMin)) else (),
        if ($dateMax != "") then map:entry("dateMax", distinct-values($dateMax)) else ()
    )
    let $r := app:doSearch($data, map:new($parts), $exact),
        $subseq := subsequence($r, $fromResult, $maxResults)
    return 
        <div class="row-fluid" xmlns="http://w3.org/1999/xhtml">
            <div class="span8">{
                if (count($r) = 0)
                then ()(:<p>Please provide some search parameters.</p>:)
                else ( 
                    <p>Results {$fromResult}-{$fromResult + count($subseq) -1}</p>,
                    if (count($r) gt $maxResults)
                    then 
                        <div class="pagination">
                            <ul>
                              <!--<li>
                                <a href="#" aria-label="Previous">
                                  <span aria-hidden="true">&laquo;</span>
                                </a>
                              </li>-->
                              {for $l in 1 to xs:integer(round(count($r) div $maxResults)) return
                              if ($l = 1)
                              then <li>{if ($fromResult = 1) then attribute class {"active"} else ()}
                                        <a href="?fromResult={$l}">{$l}</a>
                                   </li>
                              else <li>{if ($fromResult = 1 + ((xs:integer($l) - 1) * $maxResults)) then attribute class {"active"} else ()}
                                        <a href="?fromResult={(xs:integer($l) -1) * $maxResults + 1}">{$l}</a>
                                   </li>}
                              <!--<li>
                                <a href="#" aria-label="Next">
                                  <span aria-hidden="true">&raquo;</span>
                                </a>
                              </li>-->
                            </ul>
                        </div>
                      else (),
                    <ul class="thumbnails">{
                        for $s in $subseq
                        let $tablet-id := root($s)/tei:TEI/@xml:id,
                            $g-url :=  root($s)//tei:graphic[@xml:id = replace($s/@facs,'#','')]/@url,
                            $url := "$app-root/data/tablets/"||$tablet-id||"/"||$g-url
                        let $sign := $s/@type,
                            $reading := $s/text(),
                            $context := $s/parent::tei:seg[@type = 'context'] 
                        return <li class="span2 gThumbnail">
                                    <a href="annotate.xql?t={$tablet-id}&amp;s={$g-url/ancestor::tei:surface/tei:graphic/encode-for-uri(@url)}&amp;a={substring-after($s/@xml:id, 'glyph_')}" class="thumbnail">
                                        <img src="{$url}" alt=""/>
                                        {app:renderAttributes($s)}
                                    </a>
                               </li>
                    }</ul>,
                    if (count($r) gt $maxResults)
                    then 
                        <div class="pagination">
                            <ul>
                              <!--<li>
                                <a href="#" aria-label="Previous">
                                  <span aria-hidden="true">&laquo;</span>
                                </a>
                              </li>-->
                              {for $l in 1 to xs:integer(round(count($r) div $maxResults)) return
                              if ($l = 1)
                              then <li><a href="?fromResult={$l}">{$l}</a></li>
                              else <li><a href="?fromResult={(xs:integer($l) -1) * $maxResults + 1}">{$l}</a></li>}
                              <!--<li>
                                <a href="#" aria-label="Next">
                                  <span aria-hidden="true">&raquo;</span>
                                </a>
                              </li>-->
                            </ul>
                        </div>
                      else ()
            )}</div>
            <div class="span4">
                <h3>Facets</h3>
                <div>
                    {
                    for $facet in search:facets($subseq)/*
                    let $name := $facet/@name,
                        $values := $facet/*/*
                    (:order by $name:)
                    return
                    if (every $v in $values satisfies $v = '')
                    then ()
                    else
                        <div>
                            <h4>{(
                                (: attach CSS class :)
                                if ($name = $facets) 
                                then attribute class {"facet-selected"} 
                                else (), 
                                
                                (: index name and number of distinct facet values :)
                                $name||" ("||count($values[.!=''])||")",
                                
                                if ($name = $facets) 
                                then 
                                    let $url := concat(
                                                    "search.html?",
                                                    string-join(
                                                        (for $p in $parts
                                                            let $index := map:keys($p),
                                                                $value := map:get($p, $index)
                                                            return 
                                                                if ($name = $index)
                                                                then ()
                                                                else 
                                                                    for $v in $value return concat($index, "=", $v),
                                                        'facets='||string-join($facets[. != $name],','),
                                                        'fromResult='||$fromResult,
                                                        'maxResults='||$maxResults
                                                    ),'&amp;')
                                      )
                                    return <a href="{$url}" class="rmFacet" title="remove facet"><span class="icon-remove"/></a> 
                                else ()
                            )}</h4>
                            {if ($name = $facets) 
                            then $values
                            else 
                                <ul>{
                                    for $value in $values[.!='']
                                    order by $value
                                    return
                                        let $url := concat(
                                            "search.html?",
                                            string-join(
                                                (
                                                    for $p in $parts return
                                                        for $v in map:get($p,map:keys($p))
                                                        return concat(map:keys($p),"=",$v),
                                                    'fromResult='||$fromResult,
                                                    'maxResults='||$maxResults,
                                                    'facets='||string-join(($facets,$name),',')
                                                ),'&amp;')
                                            )
                                        return
                                        <li>
                                            <a href="{$url||"&amp;"||$name||"="||$value}">{$value||" ("||$value/@occurences||")"}</a>
                                        </li>
                                }</ul>
                            }
                        </div>
                    }</div>
            </div>
        </div>
};

(:~ The function app:doSearch iterates over all search parameters in the provided map $parts, 
 : calling itself recursively until all have been processed. 
 : @param $data a sequence of 0-n tei:g elements representing all or a subset of annotations in the database
 : @param $parts a map containing query parameters (map keys = parameter name)
 : @param $exact indicating if the query parameter should be interpreted as a substring on the data
 : @return 0-n tei:g elements repesenting a subset of annotations in the database
 :)
declare function app:doSearch($data as item()*, $parts as map(), $exact as xs:boolean) {
   let $keys := map:keys($parts)
   return
        if (count($keys) = 0)
        then $data
        else app:doSearch(
                search:search($data, $keys[1], map:get($parts,$keys[1]), $exact), 
                map:new(for $k in $keys[position() gt 1] return map:entry($k, map:get($parts, $k))), 
                $exact
            )
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