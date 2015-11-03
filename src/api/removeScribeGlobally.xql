xquery version "3.0";

(:~ 
 : This XQuery removes a scribe from all instances in the database. 
 : TODO: When implementing a user/editor system, make sure that only 
 : editors can execute this script.   
~:)

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "text/xml";
declare option output:exclude-result-prefixes "tei";
declare option output:indent "no";

import module namespace tablet="http://www.oeaw.ac.at/acdh/cfdb/tablet" at "xmldb:exist://db/apps/cfdb/modules/tablet.xqm";
import module namespace config="http://www.oeaw.ac.at/acdh/cfdb/config" at "xmldb:exist://db/apps/cfdb/modules/config.xqm";

declare variable $data external;

let $input := util:parse($data)
return 
    if ($input/data/tei:persName)
    then
        let $scribeName := $input/data/tei:persName/text(),
            $log := util:log-app("DEBUG", "cfdb", $scribeName),
            $occurences := collection($config:tablets-root)//tei:persName[@role = 'scribe'][text() eq $scribeName],
            $log := util:log-app("DEBUG", "cfdb", $occurences),
            $noOcc := count($occurences)
        let $remove := update value $occurences with ""
        return <data xmlns=""><tei:note type="returnMsg">Removed {$noOcc} references of {$scribeName}.</tei:note></data> 
    else <data xmlns=""><tei:note type="returnMsg">Scribe Name could not be determined, database has not been altered.</tei:note></data> 