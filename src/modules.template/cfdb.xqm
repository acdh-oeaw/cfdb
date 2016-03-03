xquery version "3.0";

module namespace cfdb = "@app.uri@/db";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config = "@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";
import module namespace annotations = "@app.uri@/annotations" at "xmldb:exist:///db/apps/@app.name@/modules/annotations.xqm";


(:~ module containing functions and variables common to the model on database level
 : NB configuration options are set under config.xqm
 :)
declare variable $cfdb:stdSigns :=  
    for $s at $pos in cfdb:listStdSigns()
    let $n := xs:integer(replace($s/@n,'\P{N}','')) 
    order by $n ascending
    return $s;

declare variable $cfdb:stdSign-position-by-charname := 
    map:new(
        for $s at $pos in $cfdb:stdSigns
        return map:entry($s/tei:charName, $pos)
    );
    
declare variable $cfdb:stdSign-by-position := 
    map:new(
        for $s at $pos in $cfdb:stdSigns
        return map:entry($pos, $s)
    );
    
declare function cfdb:stdSign-by-charname($n as xs:string) {
    let $data := $config:data-root||"/etc/stdSigns/stdSigns.xml"
    return doc($data)//tei:char[tei:charName = $n]
};
 
(: lists all standard signs in the database :)
declare function cfdb:listStdSigns() as element(tei:char)* {
    let $data := $config:data-root||"/etc/stdSigns/stdSigns.xml"
    return doc($data)//tei:char
};

(: lists all annotations in the database :)
declare function cfdb:list-annotations() {
    cfdb:list-annotations((), (), (), (), ())
};

declare function cfdb:list-annotations($category as xs:string?, $value as xs:string*) {
    cfdb:list-annotations($category, $value, (), (), ())
};

declare function cfdb:list-annotations($category as xs:string?, $value as xs:string*, $after as xs:integer, $before as xs:integer) {
    cfdb:list-annotations($category, $value, $after, $before, (), ())
};

(: lists all annotations in the database, optionally filtering by a given $category and value, grouped by one or more group clasuses and with a min/max date border applied :)
declare function cfdb:list-annotations($category as xs:string?, $value as xs:string*, $after as xs:integer?, $before as xs:integer?, $groupby-input as xs:string*, $collapse-signs as xs:boolean?) {
    let $groupby := $groupby-input[. = $config:valid-grouping-keys]
    let $glyphs := 
        if ($category = "sign-type") then collection($config:tablets-root)//tei:g[@type = $value] else
        if ($category = "sign-number") then collection($config:tablets-root)//tei:g[@n = $value] else
        if ($category = "id") then collection($config:tablets-root)//tei:g[@xml:id = $value] else
        if ($category = "place") then collection($config:tablets-root)//tei:g[root(.)//tei:origPlace/tei:placeName = $value] else
        if ($category = "period") then collection($config:tablets-root)//tei:g[root(.)//tei:creation/tei:date/@period = $value] else
        if (not(exists($category))) then collection($config:tablets-root)//tei:g
        else ()
    let $annotations := $glyphs!annotations:get-attributes(., ()) 
    let $annotations-filtered := 
        for $a in $annotations 
        let $date-min := if ($a//date-min castable as xs:integer) then xs:integer($a//date-min) else (),
            $date-max := if ($a//date-max castable as xs:integer) then xs:integer($a//date-max) else ()
        let $include-before := if (exists($before)) then $before lt $date-min else true(),
            $include-after := if (exists($after)) then $after gt $date-max else true()
        order by ($date-min, $date-max)[1] descending
        return 
            if (not(exists($date-max) or exists($date-min))) then ()
            else if (every $i in ($include-before, $include-after) satisfies $i eq true())
            then $a
            else ()
    return
    if (every $g in $groupby satisfies $g = '') 
    then <annotations items="{count($annotations-filtered)}">{$annotations-filtered}</annotations>
    else 
        let $groups := 
            for $group in $annotations-filtered
                let $period := $group//period,
                    $place := $group//place,
                    $scribe := $group//scribe,
                    $archive := $group//archive 
                let $groupValue := string-join(
                    for $gEx in $groupby
                    let $prefix := if (count($groupby) gt 1) then $gEx||": " else ""
                    return 
                        switch ($gEx)
                        case "archive" return $prefix||($archive, "[n/a]")[. != ""][1]
                        case "period" return $prefix||($period, "[n/a]")[. != ""][1]
                        case "region" return $prefix||($place, "[n/a]")[. != ""][1]
                        case "scribe" return $prefix||($scribe, "[n/a]")[. != ""][1]
                        default return "[unknown grouping clause '"||$gEx||"']"
                    , ", ")
            group by $groupValue
            order by $groupValue ascending
            return <group grouping-clause="{$groupby}" grouping-value="{$groupValue}" items="{count($group)}">{$group}</group> 
        return 
            <annotations items="{count($annotations-filtered)}" groups="{count($groups)}">{
                for $gr in $groups order by $gr/@items descending return $gr
            }</annotations>
};

(:~
 : This function lists all tablets in the database as TEI elements.
 : @return zero or more tei:TEI elements
 :)
declare function cfdb:tablets() as element(tei:TEI)* {
    cfdb:tablets(())
};

(:~
 : This function lists all tablets in the database as TEI elements, applying zero or more filters on specific attributes. 
 : Filters are combined using the AND operator after calling the cfdb:filter-tablets() function for each constraint.   
 : @param $filters zero or more <code>filter</code> elements with an attribute <code>key</code> containing the name of a defined attribute.
 : @return zero or more tei:TEI elements
 :)
declare function cfdb:tablets($filters as element(filter)*) as element(tei:TEI)* {
    let $activeFilters := $filters[not(. = ('','0'))]
    let $items := 
        if (count($activeFilters) ge 1)
        then cfdb:filter-tablets($activeFilters, ())
        else collection($config:tablets-root)//tei:TEI
    return $items 
};

(:~ This function executes the filtering recursively by calling <code>cfdb:tablet-by-facet()</code> (thus returning a set of tablets that 
 : satisfy the given constraint) and creates an intersection with a set of tei:TEI elements from previous filter operations.
 : 
 :)
declare %private function cfdb:filter-tablets($filters as element(filter)+, $results as element(tei:TEI)*){
    let $facet := cfdb:tablet-by-facet($filters[1]/@key, $filters[1])/ancestor-or-self::tei:TEI
    return
        if (count($filters) = 1)
        then 
            if ($results)
            then $facet intersect $results
            else $facet
        else 
            if ($results)
            then cfdb:filter-tablets(subsequence($filters, 2), $facet intersect $results)
            else cfdb:filter-tablets(subsequence($filters, 2), $facet)
};



(:~
 : This function searches directly within the tables collection on various defined facets of a tablet and returns the element(s) found.
 : How the filterValue will matched against the data (exact match, contains, case insensitive) depends on the facet.  
 : 
 : @param key: the key of a named faced
 : @param filterValue: the value of the faced to be searched for 
 :)
declare %private function cfdb:tablet-by-facet($key as xs:string, $filterValue as item()) as node()* {
    let $value := if ($filterValue = "[null]") then "" else $filterValue
    let $facet := 
        switch ($key)
            case "text"             return collection($config:tablets-root)//tei:msIdentifier/tei:idno[. = $value]
            case "title"            return collection($config:tablets-root)//tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[contains(., $value)]
            case "region"           return collection($config:tablets-root)//tei:msIdentifier/tei:region[contains(., $value, "?strength=secondary")]
            case "archive"          return collection($config:tablets-root)//tei:collection[@type = "archive"][contains(., $value, "?strength=secondary")]
            case "dossier"          return collection($config:tablets-root)//tei:collection[@type = "dossier"][contains(., $value, "?strength=secondary")]
            case "scribe"           return collection($config:tablets-root)//tei:persName[@role = "scribe"][contains(., $value, "?strength=secondary")]
            case "city"             return collection($config:tablets-root)//tei:origPlace/tei:placeName[contains(., $value, "?strength=secondary")]
            case "period"           return collection($config:tablets-root)//tei:origDate/tei:date[@calendar = '#gregorian'][contains(@period, $value)]
            case "anteQuem"         return collection($config:tablets-root)//tei:origDate/tei:date[@calendar = '#gregorian'][contains(@notAfter, $value)]
            case "postQuem"         return collection($config:tablets-root)//tei:origDate/tei:date[@calendar = '#gregorian'][contains(@notAfter, $value)]
            case "date"             return collection($config:tablets-root)//tei:origDate/tei:date[@calendar = '#gregorian'][contains(@notAfter, $value)]
            case "dateBabylonian"   return collection($config:tablets-root)//tei:origDate/tei:date[@calendar = '#babylonian'][. = $value]
            case "ductus"           return collection($config:tablets-root)//tei:f[@name = 'ductus'][tei:symbol/@value = $value]
            default return ()
    return $facet
};


(:~ This helper function constructs a JSON array. :)
declare function cfdb:array($objects as xs:string*) {
    concat("[", string-join($objects, ","), "]") 
};

(:~ This helper function constructs a JSON object skeleton. :)
declare function cfdb:object($properties as xs:string*) {
    concat("{", string-join($properties, ","), "}") 
}; 

(:~ This helper function constructs a JSON object property :) 
declare function cfdb:property($key as xs:string, $value) {
    concat(
        '"',$key,'"',
        ':',
        switch(true())
            (: no quotation marks around arrays or numbers :)
            case (matches($value, '^\[.+\]$')) return () 
            case ($value instance of xs:integer) return ()
            default return  '"',
        $value,
        switch(true())
            (: no quotation marks around arrays or numbers :)
            case (matches($value, '^\[.+\]$')) return ()
            case ($value instance of xs:integer) return ()
            default return  '"'
    )
}; 


declare function cfdb:ls($path) {
    cfdb:ls($path, ())
};

declare function cfdb:ls($path, $mime-type-filter as xs:string*) {
    <collection path="{$path}" name="{tokenize($path,'/')[last()]}">{
        if (not(xmldb:collection-available($path)))
        then <error>Not available / no permission</error>
        else 
            (for $c in xmldb:get-child-collections($path) return cfdb:ls($path||"/"||$c, $mime-type-filter),
             for $r in xmldb:get-child-resources($path) 
                let $dbpath := $path||"/"||$r,
                    $mime-type := xmldb:get-mime-type($dbpath)
                return 
                    if (not(exists($mime-type-filter)) or $mime-type = $mime-type-filter) 
                    then <resource path="{$dbpath}" mime-type="{$mime-type}">{$r}</resource>
                    else ()
            )
    }</collection>
};
