xquery version "3.0";

module namespace api = "http://www.oeaw.ac.at/acdh/cuneidb/api";

import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";
import module namespace cfdb = "http://www.oeaw.ac.at/acdb/cuneidb/db" at "xmldb:exist:///db/apps/cuneidb/modules/cfdb.xqm";
import module namespace tablet = "http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";
import module namespace surface = "http://www.oeaw.ac.at/acdh/cuneidb/surface" at "xmldb:exist:///db/apps/cuneidb/modules/surface.xqm";
import module namespace annotation = "http://www.oeaw.ac.at/acdb/cuneidb/annotations" at "xmldb:exist:///db/apps/cuneidb/modules/annotations.xqm";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function api:response($caller as xs:string, $items as map()*) as element(api:reponse) {
    <response xmlns="http://www.oeaw.ac.at/acdh/cuneidb/api">
        <metadata>
            <query>{$caller}</query>
            <timeStamp>{current-dateTime()}</timeStamp>
            <user>{xmldb:get-current-user()}</user>
        </metadata>
        <body>{
            for $i in $items
            return    
                <item>{
                    for $k in map:keys($i) 
                    let $name := string-join((
                        for $t at $p in tokenize($k,'\s+') 
                        return  
                            if ($p = 1) 
                            then lower-case($t)
                            else upper-case(substring($t,1,1))||lower-case(substring($t,2)) 
                    ),'')
                    return <property name="{$name}">{map:get($i,$k)}</property>
                }</item>
        }</body>
    </response>
};

declare function api:status($status, $msg) {
    let $load := <cfdb:response><status>{$status}</status><msg>{$msg}</msg></cfdb:response>
    let $statusCode := 
        switch(true())
            case $status = "error" return 500
            default return 200
    return 
        (<rest:response>
            <http:response status="{$statusCode}">
                {if ($statusCode != 200) then attribute reason {$msg} else ()}
            </http:response>            
        </rest:response>,
        $msg)
};


declare function api:log($msg) as empty() {
    if ($config:debug)
    then 
        try {  
            util:log-app("DEBUG", $config:app-name, $msg||" ["||xmldb:get-current-user()||"@"||request:get-remote-addr()||"]")
        } catch * {
            util:log-app("DEBUG", $config:app-name, $msg)
        }
    else ()
};





(: **** SURFACE **** :)
(:~ delete a surface :)
declare 
    %rest:DELETE
    %rest:path("/cfdb/tablets/{$tablet-id}/surfaces/{$surface-id}")
function api:delete-surface($tablet-id as xs:string, $surface-id as xs:string) {
    let $tablet := tablet:get($tablet-id)
    let $delete := 
        if (exists($tablet))
        then surface:delete(tablet:get($tablet-id), $surface-id)
        else map {"status" := "error" , "msg" := "tablet with id "||$tablet-id||" not available"}
    return api:status($delete("status"), $delete("msg"))
};

(:~ create a new surface :)
declare 
    %rest:POST("{$data}")
    %rest:path("/cfdb/tablets/{$tablet-id}/surfaces")
    %rest:query-param("type", "{$type}")
    %rest:query-param("filename", "{$filename}")
    %rest:query-param("width", "{$width}")
    %rest:query-param("height", "{$height}")
function api:add-surface($tablet-id as xs:string, $data as item(), $type as xs:string*, $filename as xs:string*, $width as xs:integer*, $height as xs:integer*) {
    let $tablet := tablet:get($tablet-id)
    let $create := 
        switch (true())
            case (not($tablet)) return map{"status" := "error", "msg" := "tablet "||$tablet-id||" not found"}
            case ($type = '' and $filename = '') return map{"status" := "error", "msg" := "either parameter filename or type must be provided"}
            case (not($width)) return map{"status" := "error", "msg" := "parameter width must not be empty"}
            case (not($height)) return map{"status" := "error", "msg" := "parameter height must not be empty"}
            case (not(exists($data))) return map{"status" := "error", "msg" := "uploaded data missing"}
            default return surface:new($tablet, $type[1], $filename[1], xs:integer($width[1]), xs:integer($height[1]), $data)
    return api:status($create("status"), $create("msg"))
};

declare 
    %rest:GET
    %rest:path("/cfdb/tablets/{$tablet-id}/surfaces")
    %rest:produces("application/json")
    %output:media-type("application/json")
function api:list-surfaces($tablet-id as xs:string) {
    let $tablet := tablet:get($tablet-id)
    let $surfaces := tablet:listSurfaces($tablet)
    let $response := <cfdb:response>{
            for $s in $surfaces 
            return <surface>
                        <name>{$s/tei:graphic/util:unescape-uri(xs:string(@url),'utf-8')}</name>
                        <id>{$s/tei:graphic/xs:string(@url)}</id>
                   </surface>
        }</cfdb:response>
    return util:serialize($response,"method=json")
};


(: ********** ANNOTATIONS *********:)

(:~ lists annotations in a given surface :)
declare 
    %rest:GET
    %rest:path("/cfdb/tablets/{$tablet-id}/surfaces/{$surface-id}/annotations")
    %rest:form-param("filter", "{$filter}")
    %rest:produces("application/json")
    %output:media-type("application/json")
function api:list-annotations($tablet-id as xs:string, $surface-id as xs:string, $filter as xs:string*) {
    let $tablet := tablet:get($tablet-id)
    return 
        if (exists($tablet))
        then 
            let $annos := surface:list-annotations($tablet, $surface-id, $filter),
                $response := <cfdb:response>{$annos}</cfdb:response> 
            return util:serialize($response,"method=json")
        else "tablet with id "||$tablet-id||" not available"
};


declare 
    %rest:GET
    %rest:path("/cfdb/tablets/{$tablet-id}/surfaces/{$surface-id}/annotations/{$annotation-id}")
    %rest:form-param("filter", "{$filter}")
    %rest:produces("application/json")
    %output:media-type("application/json")
function api:read-annotation($tablet-id as xs:string, $surface-id as xs:string, $annotation-id as xs:string, $filter as xs:string*) {
    let $tablet := tablet:get($tablet-id)
    return 
        if (exists($tablet))
        then annotation:read($tablet, $surface-id, $annotation-id, $filter) 
        else "tablet with id "||$tablet-id||" not available"
};

declare
    %rest:POST("{$data}")
    %rest:path("/cfdb/tablets/{$tablet-id}/surfaces/{$surface-id}")
    %rest:produces("application/json")
    %output:media-type("application/json")
function api:create-annotation($data as xs:string, $tablet-id as xs:string, $surface-id as xs:string) {
    let $tablet := tablet:get($tablet-id)
    return 
        if (exists($tablet))
        then annotation:new($data, $tablet, $surface-id)
        else "tablet with id "||$tablet-id||" not available"
}; 

(:~ update an existing annotation
 :)
declare
    %rest:PUT("{$data}")
    %rest:path("/cfdb/tablets/{$tablet-id}/surfaces/{$surface-id}/annotations/{$annotation-id}")
    %rest:produces("application/json")
    %output:media-type("application/json")
function api:update-annotation($data as xs:string, $tablet-id as xs:string, $surface-id as xs:string, $annotation-id as xs:string) {
    let $tablet := tablet:get($tablet-id)
    return 
        if (exists($tablet))
        then annotation:update($data, $tablet-id, $surface-id, $annotation-id) 
        else "tablet with id "||$tablet-id||" not available"
};

(:~ delete an annotation :)
declare 
    %rest:DELETE
    %rest:path("/cfdb/tablets/{$tablet-id}/surfaces/{$surface-id}/annotations/{$annotation-id}")
function api:delete-annotation($tablet-id as xs:string, $surface-id as xs:string, $annotation-id as xs:string) {
    annotation:delete(tablet:get($tablet-id), $surface-id, $annotation-id)
};



(:~ list all annotions standard signs :)
declare 
    %rest:GET
    %rest:path("/cfdb/taxonomies/signs")
    %rest:produces("application/json")
    %output:media-type("application/json")
function api:list-std-signs() {
    cfdb:listStdSigns()
};

