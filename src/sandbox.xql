xquery version "3.0";

import module namespace config="http://www.oeaw.ac.at/acdh/cfdb2/config" at "modules/config.xqm";
import module namespace tablet="http://www.oeaw.ac.at/acdh/cfdb2/tablet" at "modules/tablet.xqm";

let $id := "K_961"
return tablet:get($id)