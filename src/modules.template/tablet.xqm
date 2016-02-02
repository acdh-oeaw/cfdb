xquery version "3.0";

module namespace tablet = "@app.uri@/tablet";

import module namespace config="@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";
import module namespace surface="@app.uri@/surface" at "xmldb:exist:///db/apps/@app.name@/modules/surface.xqm";
import module namespace annotation = "@app.uri@/annotations" at "xmldb:exist:///db/apps/@app.name@/modules/annotations.xqm";
import module namespace cfdb = "@app.uri@/db" at "xmldb:exist:///db/apps/@app.name@/modules/cfdb.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $tablet:template-filepath := $config:app-root||"/tabletTpl.xml";
declare variable $tablet:template := doc($tablet:template-filepath);

declare variable $tablet:seed-xsl-filepath := $config:app-root||"/seed.xsl";
declare variable $tablet:seed-xsl := doc($tablet:seed-xsl-filepath);

(:~ This module combines function that operate on one single tablet. 
 : Operations on more than one tablet are kept under cfdb.xqm, 
 : operations on annotations under annotations.xqm
:)

(:~
 : stores a new tablet document (based on form data) by creating a collection 
 : inside of $config:tablets-root and storing the data in there.
 : TODO rename result map key name "outcome" to "status" () 
 : 
 : @param $tei the TEI file as an tei:TEI element
 : @return a map containing the mandatory fields "outcome" and "msg"
:)
declare function tablet:new($tei as element(tei:TEI)) as map() {
 	(: because of the Image Markup Tool being picky with 
 	: data which is not in the default namespace, we have to 
 	: do an identity transform in order to get rid of any 
 	: spurious namespace prefixes :)
    let $id := $tei/@xml:id
    let $create-collection := xmldb:create-collection($config:tablets-root,$id)
    let $collection-created := 
    	if ($create-collection)
    	then util:log-app("INFO",$config:app-name,"Created collection for new tablet "||$id)
    	else (util:log-app("INFO",$config:app-name,"An error occured. Could not create collection "||$id||" in "||$config:tablets-root),false())
    let $store-tei := 
        try {
            xmldb:store($config:tablets-root || "/" || $id ,
            			$id||".xml", 
            			$tei)
        } catch * {
            util:log-app("INFO",$config:app-name,"An error occured. Could not store tablet "||$id||".")
        }
	let $setACL := 
	   if ($create-collection and $store-tei)
	   then (
	       sm:add-group-ace($create-collection, "cfdbAnnotators", true(), "r-x"),
	       sm:add-group-ace($create-collection, "cfdbEditors", true(), "rwx"),
	       sm:add-group-ace($store-tei, "cfdbEditors", true(), "rwx")
	   )
	   else ()
	let $returnVal := 
		if ($create-collection and $store-tei)
		then true()
		else false()
	
	let $msg := 
		if ($returnVal)
		then "Tablet has been created."
		else "An error occured storing the tablet."
	return 
		map {"outcome" := $returnVal, "message" := $msg}	 
};


(: sets the access control list for the given paths
 : NB by now every cfdb group member can do everything, this will be subject to change
 : @param $paths one or more strings containing db-paths
 :)
declare function tablet:setACL($paths as xs:string+) {
    for $p in $paths
    return sm:add-group-ace($p, "cuneiformDB", true(), "rwx")
};


(:~ retrieves the tablet identified by its id 
 : @param $id the tablet's id 
 : @return the tablet's tei:TEI element 
 :)
declare function tablet:get($id as xs:string) as element(tei:TEI)? {
    collection($config:tablets-root)//tei:TEI[tei:sourceDoc][@xml:id = $id]
};


(:~ retrieves the id of the given tablet
 : @param $tablet the tablet as a tei:TEI element
 : @return a string with the tablet's id 
 :)
declare function tablet:id($tablet as element(tei:TEI)) as xs:string {
    $tablet/xs:string(@xml:id)
};



(:~ removes all data of the given tablet
 : @param $tablet the tablet as a tei:TEI element
 : @return empty sequence
 :)
declare function tablet:remove($tablet as element(tei:TEI)) as empty() {
    (:let $data := tablet:get($id),
        $filepath := base-uri($data),
        $filename := tokenize($filepath,'/'),
        $path := substring-before('/'||$filename,$filepath)
    return xmldb:remove($path,$filename):)
    xmldb:remove(tablet:path($tablet))
};


(:~ lists all tablets in the database 
 : DEPRECATED 
 : the getter functionality moved to cfdb module/namespace, 
 : the (simplified) XML representation is provided by api/lsTablets.xql,
 : the JSON representation is provided by the RESTXQ endpoint at modules/api.xqm 
 : @return zero or more maps with the mandadory fields "id", "title", "filename" and "path"
 :)
declare function tablet:list() as map()* {
    let $map :=  
        for $d in cfdb:tablets() 
        return 
        map{
            "id" 		:= $d/xs:string(@xml:id),
            "title" 	:= $d/tei:teiHeader/tei:fileDesc/tei:titleStmt/data(tei:title),
            "filename"	:= util:document-name($d),
           	"path"		:= util:collection-name($d)
        }
    let $log := util:log-app("DEBUG", $config:app-name, "tablet:list -- found "||count($map)||" tablets")
    return $map
};


(:~ returns the db base path containing all tablet data (source, img and derivates)
 : @param $tablet the tablet as a tei:TEI element
 : @return db-path as a string 
 :)
declare function tablet:path($tablet as element(tei:TEI)) as xs:string? {
    util:collection-name($tablet)
};


(:~
 : lists data in the tablet's collection, possibly filtering by one ore more mime-types.
 : @param $tablet the tablet as a tei:TEI element
 : @param $mime-type-filter sequence of mime-types to find (optional)
 : @return full db-paths for each resource 
~:)
declare function tablet:listResources($tablet as element(tei:TEI)) as element(collection)? {
	tablet:listResources($tablet,())
};

(:~
 : lists data in the tablet's collection, possibly filtering by one ore more mime-types.
 : @param $tablet the tablet as a tei:TEI element
 : @param $mime-type-filter sequence of mime-types to find (optional)
 : @return full db-paths for each resource 
~:)
declare function tablet:listResources($tablet as element(tei:TEI), $mime-type-filter as xs:string*) as element(collection)? {
    let $col := tablet:path($tablet)
    let $col-available := xmldb:collection-available($col)
    let $resources :=
    	if (not($col-available))
    	then util:log-app("INFO",$config:app-name,"Collection "||$col||" not found.")
    	else cfdb:ls($col, $mime-type-filter)
    return $resources
};

(:~ returns all surfaces in the given tablet
 : @param $tablet the tablet as a tei:TEI element 
 : @return zero or more tei:surface elements
 :)
declare function tablet:listSurfaces($tablet as element(tei:TEI)) as element(tei:surface)*  {
    $tablet/tei:sourceDoc/tei:surface
};

(:~ returns 1-n maps containing values of given attributes for a given tablet
 : NB The list of fields should at least contain the ones used by the jSGrid (resources/js/jsGrid.js)
 : @param $id the ID of the tablet
 : @param $attributes 1-n names of attributes  
 : @return a map with one key for each attribute value
 :)
declare function tablet:get-attributes($id as xs:string) as map() {
     tablet:get-attributes($id, ("id", "text", "period", "date-babylonian", "date", "postQuem", "anteQuem", "region", "archive", "dossier", "scribe", "ductus", "editable"))
};

(:~ returns 1-n maps containing values of given attributes for a given tablet
 : @param $id the ID of the tablet
 : @param $attributes 1-n names of attributes  
 : @return a map with one key for each attribute value
 :)
declare function tablet:get-attributes($id as xs:string, $attributes as xs:string+) as map() {
    let $tablet := tablet:get($id)
    let $data := for $a in $attributes return map:entry($a, tablet:index2data($tablet, $a))
    return map:new($data)
};

(:~ updates the value of a given attribute on a given tablet
 : @param $id the ID of the tablet
 : @param $attribute name of 1 attribute
 : @param $value the new value
 : @return the updated tablet 
 :)
declare function tablet:set-attribute($id as xs:string, $attribute as xs:string, $value as xs:anyAtomicType) as map() {
    let $tablet := tablet:get($id)
    let $data := tablet:index2node($tablet, $attribute)
    let $update := update value $data with $value
    return tablet:get-attributes($id)
};

(:~ returns the value of the given attribute on any node of a tablet
 : @param $node a node on a tablet
 : @param $attribute the name of one attribute 
 : @return the node containing the attribute value  
 :)
declare %private function tablet:index2node($node as node(), $attribute as xs:string) as node()? {
    let $tablet := $node/ancestor-or-self::tei:TEI
    return
    if (not(exists($tablet)))
    then ()
    else 
        switch($attribute)
            case "id" return $tablet/@xml:id 
            case "text" return $tablet//tei:sourceDesc/tei:msDesc/tei:msIdentifier/tei:idno[1]
            case "period" return $tablet//tei:origDate/tei:date/@period
            case "date-babylonian" return $tablet//tei:origDate/tei:date[@calendar = '#babylonian']
            case "date" return $tablet//tei:origDate/tei:date[@calendar = '#gregorian']
            case "postQuem" return $tablet//tei:origDate/tei:date[@calendar = '#gregorian']/@notBefore
            case "anteQuem" return $tablet//tei:origDate/tei:date[@calendar = '#gregorian']/@notAfter
            case "region" return $tablet//tei:region
            case "archive" return $tablet//tei:collection[@type='archive']
            case "dossier" return $tablet//tei:collection[@type='dossier']
            case "scribe" return $tablet//tei:persName[@role = 'scribe']
            case "ductus" return $tablet//tei:f[@name = 'ductus']/tei:symbol/@value
            default return $node
};

declare %private function tablet:index2data($node as node(), $attribute as xs:string) as xs:anyAtomicType? {
    let $node := tablet:index2node($node, $attribute)
    return 
        if ($node) 
        then 
            switch (true())
                (: should eventually become xs:integer :)
                case ($attribute = ("date-gregorian", "postQuem", "anteQuem")) return xs:string($node)
                case ($attribute = "editable") return 
                    let $owner := sm:get-permissions(base-uri($node))/*/@owner,
                        $cfdbEditors := sm:get-group-members("cfdbEditors")
                    return 
                        if (xmldb:get-current-user() = ($owner, $cfdbEditors)) 
                        then 1
                        else 0
                    
                default return xs:string($node)
        else ()
};
