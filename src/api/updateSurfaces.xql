xquery version "3.0";

declare namespace api = "http://acdh.oeaw.ac.at/cuneidb/api";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";

import module namespace tablet = "http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";
import module namespace surface = "http://www.oeaw.ac.at/acdh/cuneidb/surface" at "xmldb:exist:///db/apps/cuneidb/modules/surface.xqm";

(:~ 
 : This XQuery script updates all surface documents for a given tablet. 
 :)

declare variable $data external;

let $tablet := util:parse($data)/selectedTablet
let $id := $tablet/id

let $log := util:log-app("DEBUG", $config:app-name, "updateSurfaces.xql called for "||$id)
return tablet:updateSurfaces($id)
(:return ():)