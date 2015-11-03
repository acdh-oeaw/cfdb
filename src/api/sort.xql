xquery version "3.0";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "text/xml";
declare option output:exclude-result-prefixes "tei";

declare variable $data external;

let $input := util:parse($data),
    $by := $input/data/xs:string(@by),
    $content := $input/data/*

return 
    if ($by != '')
    then
        <data by="{$by}">{
            for $c in $content  
            order by 
                if (util:eval("$c/"||$by) castable as xs:integer) then xs:integer(util:eval("$c/"||$by))
                else util:eval("$c/"||$by)
            return $c
        }</data>
        
    else $input