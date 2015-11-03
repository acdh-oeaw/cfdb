xquery version "3.0";

module namespace api = "http://www.oeaw.ac.at/acdh/cfdb/api";

import module namespace config="http://www.oeaw.ac.at/acdh/cfdb/config" at "xmldb:exist:///db/apps/cfdb/modules/config.xqm";
import module namespace cfdb = "http://www.oeaw.ac.at/acdh/cfdb/db" at "xmldb:exist:///db/apps/cfdb/modules/cfdb.xqm";
import module namespace tablet = "http://www.oeaw.ac.at/acdh/cfdb/tablet" at "xmldb:exist:///db/apps/cfdb/modules/tablet.xqm";
import module namespace surface = "http://www.oeaw.ac.at/acdh/cfdb/surface" at "xmldb:exist:///db/apps/cfdb/modules/surface.xqm";
import module namespace annotation = "http://www.oeaw.ac.at/acdh/cfdb/annotations" at "xmldb:exist:///db/apps/cfdb/modules/annotations.xqm";


declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function api:response($caller as xs:string, $items as map()*) as element(api:reponse) {
    <response xmlns="http://www.oeaw.ac.at/acdh/cfdb/api">
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
            case $status = "error"          return 500
            case $status = "unauthorized"   return 401
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



(: **** TABLETS **** :)
(: list tablets (only GET is supported on this endpoint) :)
declare 
    %rest:GET
    %rest:path("/cfdb/tablets")
    %rest:produces("application/json")
    %output:media-type("application/json")
function api:list-tablets() {
    let $tablets := cfdb:tablets(),
        $user := xmldb:get-current-user(),
        $log := util:log-app("DEBUG", $config:app-name, "api:list-tablets() called by "||$user)
    let $response := <cfdb:response>{
            for $t in $tablets
                let $id := $t/xs:string(@xml:id),
                    $title := $t/tei:teiHeader/tei:fileDesc/tei:titleStmt/data(tei:title),
                    $filename := util:document-name($t),
           	        $path := util:collection-name($t),
           	        $permissions := sm:get-permissions($path),
           	        $editable := if ($permissions/*/@owner = $user or $user = $config:superusers) then true() else false()
            return  <tablet editable="{if ($editable) then 1 else 0}">
                  		<id>{$id}</id>
                  		<path>{$path}</path>
                  		<title>{$title}</title>
                  	</tablet>
        }</cfdb:response>
    return 
        if ($user = $config:authorized-users)
        then util:serialize($response,"method=json")
        else api:status("unauthorized", "You are not allowed to access this service")
};


(: **** SURFACE **** :)
(:~ delete a surface :)
declare 
    %rest:DELETE
    %rest:path("/cfdb/tablets/{$tablet-id}/surfaces/{$surface-id}")
    %rest:produces("application/json")
    %output:media-type("application/json")
function api:delete-surface($tablet-id as xs:string, $surface-id as xs:string) {
    let $tablet := tablet:get($tablet-id)
    let $delete := 
        if (exists($tablet))
        then surface:delete(tablet:get($tablet-id), $surface-id)
        else map {"status" := "error" , "msg" := "tablet with id "||$tablet-id||" not available"}
    let $response := 
        <cfdb:response>
            <surface>
                <id>{$surface-id}</id>
                <tablet-id>{$tablet-id}</tablet-id>
                <status>{$delete("status")}</status>
                <msg>{$delete("msg")}</msg>
            </surface>
        </cfdb:response>
    return util:serialize($response,"method=json")
};

(:~ create a new surface :)
declare 
    %rest:POST("{$data}")
    %rest:path("/cfdb/tablets/{$tablet-id}/surfaces")
    %rest:query-param("type", "{$type}")
    %rest:query-param("filename", "{$filename}")
    %rest:query-param("width", "{$width}")
    %rest:query-param("height", "{$height}")
    %rest:produces("application/json")
    %output:media-type("application/json")
function api:add-surface($tablet-id as xs:string, $data, $type as xs:string*, $filename as xs:string*, $width as xs:integer*, $height as xs:integer*) {
    let $tablet := tablet:get($tablet-id)
    let $create := 
        switch (true())
            case (not($tablet)) return map{"status" := "error", "msg" := "tablet "||$tablet-id||" not found"}
            case ($type = '' and $filename = '') return map{"status" := "error", "msg" := "either parameter filename or type must be provided"}
            case (not($width)) return map{"status" := "error", "msg" := "parameter width must not be empty"}
            case (not($height)) return map{"status" := "error", "msg" := "parameter height must not be empty"}
            case (not(exists($data))) return map{"status" := "error", "msg" := "uploaded data missing"}
            default return surface:new($tablet, $type[1], $filename[1], xs:integer($width[1]), xs:integer($height[1]), $data)
    let $status := $create("status"),
        $msg := $create("msg"),
        $filename := $create("filename")
    let $response := <cfdb:response>
                        <surface>
                            <name>{util:unescape-uri($filename,'utf-8')}</name>
                            <id>{$filename}</id>
                        </surface>
                    </cfdb:response>
    return util:serialize($response,"method=json")
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
                $response := <cfdb:response>{$annos}</cfdb:response>,
                $user := xmldb:get-current-user()
            return 
                if ($user = $config:authorized-users)
                then util:serialize($response,"method=json")
                else api:status("unauthorized", "You are not allowed to access this service")
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
    let $log := util:log-app("DEBUG", "cfdb", "api:read-annotation() current-user: "||xmldb:get-current-user())
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
    let $log := util:log-app("DEBUG", "cfdb", "api:update-annotation() current-user: "||xmldb:get-current-user())
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
    let $chars := cfdb:listStdSigns()
    let $response := 
        <cfdb:response>{
            for $c in $chars 
            let $name := $c/tei:charName/text()
            order by $name
            return
                <sign>
                    <id>{$c/xs:string(@xml:id)}</id>
                    <n>{$c/xs:string(@n)}</n>
                    <name>{$name}</name>
                </sign>
        }</cfdb:response>
    return util:serialize($response,"method=json")
};

(:declare 
    %rest:POST
    %rest:path("/cfdb/login")
    %rest:produces("application/json")
    %rest:header-param("user", "{$user}")
    %rest:header-param("password", "{$password}")
    %output:media-type("application/json")
function api:login($user as xs:string*, $password as xs:string*) {
    let $login := xmldb:login($config:data-root,$user[1], $password[1])
    let $session-token := <token expires="{current-dateTime() + xs:dayTimeDuration("PT1H")}">{util:uuid()}</token>
    let $store := 
        if ($login)
        then xmldb:store($config:app-root||"/data/tokens", $user||".xml", $session-token)
        else ()
    let $response := 
        <cfdb:response>
            <user>{$user}</user>
            <password>{$password}</password>
            <login-result>{$login}</login-result>
            <token>{$session-token}</token>
        </cfdb:response>
    return util:serialize($response,"method=json")
    
};:)