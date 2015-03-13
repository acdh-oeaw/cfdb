xquery version "3.0";

(:declare namespace api = "http://acdh.oeaw.ac.at/cuneidb/api";:)
declare namespace tei = "http://www.tei-c.org/ns/1.0";
import module namespace api = "http://www.oeaw.ac.at/acdh/cuneidb/api" at "xmldb:exist:///db/apps/cuneidb/modules/api.xqm";
import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";

import module namespace tablet="http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";

declare variable $data external;

let $log := util:log-app("DEBUG",$config:app-name, "viewTablet.xql called")
let $input := util:parse($data)
let $tablet-id := $input//id
return 
    if ($tablet-id='')
    then <span/>
    else 
        let $log := util:log-app("DEBUG",$config:app-name, "$tablet-id = "||$tablet-id)
        let $tablet := tablet:get($tablet-id)
        let $html := transform:transform($tablet,doc($config:tablet2html),())
        return $html