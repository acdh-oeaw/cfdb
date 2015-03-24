xquery version "3.0";

module namespace search = "http://www.oeaw.ac.at/acdh/cuneidb/search";

import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";
import module namespace cfdb = "http://www.oeaw.ac.at/acdb/cuneidb/db" at "xmldb:exist:///db/apps/cuneidb/modules/cfdb.xqm";
import module namespace tablet = "http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";
import module namespace surface = "http://www.oeaw.ac.at/acdh/cuneidb/surface" at "xmldb:exist:///db/apps/cuneidb/modules/surface.xqm";
import module namespace annotation = "http://www.oeaw.ac.at/acdb/cuneidb/annotations" at "xmldb:exist:///db/apps/cuneidb/modules/annotations.xqm";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $search:facets := ("sign", "date-babylonian", "date-gregorian", "period", "region", "archive", "dossier", "scribe");

declare function search:search($data as element(tei:g)*, $index as xs:string, $terms as xs:string*, $exact as xs:boolean?) as element(tei:g)* {
    switch($index)
        case "reading" return if ($exact) then $data[. = $terms] else for $t in $terms return $data[contains(., $t)]
        case "context" return if ($exact) then $data[parent::tei:seg = $terms] else for $t in $terms return $data[contains(parent::tei:seg, $t)]
        case "sign" return $data[@type = $terms]
        case "dateMin" return $data[root(.)//tei:origDate/tei:date[. castable as xs:integer]/xs:integer(.) ge $terms[1]]
        case "dateMax" return $data[root(.)//tei:origDate/tei:date[. castable as xs:integer]/xs:integer(.) le $terms[1]]
        case "period" return $data[root(.)//tei:origDate/tei:date/@period = $terms]
        case "date-babylonian" return $data[root(.)//tei:origDate/tei:date[@calendar = '#babylonian'] = $terms[1]]
        case "date-gregorian" return $data[root(.)//tei:origDate/tei:date[@calendar = '#gregorian'] = $terms[1]]
        case "region" return $data[root(.)//tei:region = $terms]
        case "archive" return $data[root(.)//tei:collection[@type='archive'] = $terms]
        case "dossier" return $data[root(.)//tei:collection[@type='dossier'] = $terms]
        case "scribe" return $data[root(.)//tei:persName[@role = 'scribe'] = $terms]
        default return $data
};


declare function search:facets($data as element(tei:g)*) {
    search:facets($data, $search:facets)
};

(:~ aggregates a list of the facets  
:)
declare function search:facets($data as element(tei:g)*, $facets as xs:string*) as map()* {
    for $f in $facets 
        let $values := search:facet-values($data, $f) 
        return map{ "facet" := $f, "values" := $values }
};


(:~ lists all distinct values and the number of their occurences for a given facet
 : @param $data a sequence of tei:g elements
 : @param $index the name of the facet, must be one of $search:facets
 : @return 0-n maps: key = value of the facet, value = number of instances.
 :)
declare function search:facet-values($data as element(tei:g)*, $index as xs:string) as map()? {
    map:new(
        for $d in $data
        let $x := ""
        group by $value :=   
                switch($index)
                    case "reading" return $d
                    case "context" return $d/parent::tei:seg
                    case "sign" return $d/@type
                    case "date-babylonian" return root($d)//tei:origDate/tei:date[@calendar = "#babylonian"]
                    case "date-gregorian" return root($d)//tei:origDate/tei:date[@calendar = "#gregorian"]
                    case "period" return root($d)//tei:origDate/tei:date/@period
                    case "region" return root($d)//tei:region
                    case "archive" return root($d)//tei:collection[@type = "archive"]
                    case "dossier" return root($d)//tei:collection[@type = "dossier"]
                    case "scribe" return root($d)//tei:persName[@role = "scribe"]
                    default return ()  
        return 
            if ($d = '')
            then ()
            else map:entry($value, count($d))
    )
};
