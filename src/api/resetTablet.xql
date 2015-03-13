xquery version "3.0";

import module namespace config = "http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";
import module namespace tablet = "http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";

(:~ This XQuery script delete all glyph and zone information for the tablet and rebuilds 
it from scratch from its surface documents. :) 

declare variable $data external;


let $tablet := util:parse($data)/selectedTablet
let $tablet-id := $tablet/id

let $log := util:log-app("DEBUG", $config:app-name, "resetTablet.xql called for tablet "||$tablet-id)
return 
    try {
        let $reset := tablet:reset($tablet-id)
        return 
            element {$data/name(*)} {
                $data/*/@*,
                $data/*/*,
                element {'msg'} {'reloaded Signs'}
            }
        }
    catch * {
            element {$data/name(*)} {
                $data/*/@*,
                $data/*/*,
                element {'msg'} {'an error occured'}
        }
    }