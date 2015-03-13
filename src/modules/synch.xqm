xquery version "3.0";

(:~ This XQuery is called each time a facsmile TEI document 
 : is updated. It extracts the IMT annotations in it,
 : converts them into TEI markup 
 : updates the main TEI file with it.
 :)

module namespace trigger="http://exist-db.org/xquery/trigger";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace tablet="http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";
import module namespace surface="http://www.oeaw.ac.at/acdh/cuneidb/surface" at "xmldb:exist:///db/apps/cuneidb/modules/surface.xqm";
import module namespace config = "http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";


(:~ 
 : Helper function that handles data retrieval for the document refered to by the trigger.
 : We potentially have to deal with binary docs here.
~:)
declare function local:get-data($uri as xs:anyURI) as document-node()? {
	if (util:binary-doc-available($uri)) 
	then ()
	else 
		if (doc-available($uri))
		then doc($uri)
		else ()
};




declare function local:doc-type($data as item()?) as xs:string? {
    if (exists($data/tei:TEI/tei:sourceDoc)) then "tablet"
	else if (exists($data//tei:div[@xml:id = 'imtImageAnnotations'])) then "surface"
	else ()
};



(:~ "main" functions that are called by the trigger. :)
declare function trigger:after-update-document($uri as xs:anyURI) {
    let $log := util:log-app("INFO",$config:app-name,"trigger:after-update-document("||$uri||")")
	let $data := local:get-data($uri),
		$type := local:doc-type($data)
    let $log := util:log-app("INFO",$config:app-name," $type = "||$type)
	let $update := 
		(: changes to the surface should not be transmitted to the tablet automatically but be added to a queue :)
		if ($type = "surface") then 
(:			local:updateTablet($data/tei:TEI) :)
            let $mainTEI := collection(util:collection-name($data))//tei:TEI[tei:sourceDoc]
            let $tablet-id := $mainTEI/@xml:id
            return 
                if ($tablet-id='')
                then util:log-app("ERROR",$config:app-name," could not determine tablet's id")
                else tablet:update-is-pending($tablet-id, $uri, true()) 
        else ()
	return ()
};


(:declare function trigger:before-delete-document($uri as xs:anyURI) {
    let $log := util:log-app("INFO",$config:app-name,"trigger:before-delete-document("||$uri||")")
	let $data := local:get-data($uri),
		$type := if (exists($data/tei:TEI/tei:sourceDoc)) then "tablet"
				 else if (exists($data//tei:div[@xml:id = 'imtImageAnnotations'])) then "surface"
				 else (util:log-app("INFO",$config:app-name,"$type could not be determined."))
	let $update := 
	   if ($type = "surface") then ()(\:surface:remove($uri):\)   
	   else ()
	return ()
};:)