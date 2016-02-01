xquery version "3.0";

module namespace api = "@app.uri@/api";

import module namespace config="@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";
import module namespace cfdb = "@app.uri@/db" at "xmldb:exist:///db/apps/@app.name@/modules/cfdb.xqm";
import module namespace tablet = "@app.uri@/tablet" at "xmldb:exist:///db/apps/@app.name@/modules/tablet.xqm";
import module namespace surface = "@app.uri@/surface" at "xmldb:exist:///db/apps/@app.name@/modules/surface.xqm";
import module namespace annotation = "@app.uri@/annotations" at "xmldb:exist:///db/apps/@app.name@/modules/annotations.xqm";


declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function api:response($caller as xs:string, $items as map()*) as element(api:reponse) {
    <response xmlns="@app.uri@/api">
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
(:~ list tablets as JSON 
 : @param $text: filter tablets by text reference (exact match) 
 : @param $region: filter tablets by region (case insensitive substring match)
 : @param $archive: filter tablets by archive (case insensitive substring match)
 : @param $dossier: filter tablets by dossier (case insensitive substring match) 
 : @param $scribe: filter tablets by scribe (case insensitive substring match)
 : @param $city: filter tablets by city (case insensitive substring match)
 : @param $periodd: filter tablets by period (substring match)
 : @param $anteQuem: filter tablets by anteQuem date (exact match)
 : @param $postQuem: filter tablets by anteQuem date (exact match)
 : @param $date: filter tablets by date (exact match)
 : @param $dateBabylonian: filter tablets by babylonian date (exact match)
 : @param $ductus: filter tablets by ductus attribute(exact match)
 : NB: only GET is supported on this endpoint 
 :)
declare 
    %rest:GET
    %rest:path("/cfdb/tablets")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %rest:query-param("text", "{$text}")
    %rest:query-param("region", "{$region}")
    %rest:query-param("archive", "{$archive}")
    %rest:query-param("dossier", "{$dossier}")
    %rest:query-param("scribe", "{$scribe}")
    %rest:query-param("city", "{$city}")
    %rest:query-param("period", "{$period}")
    %rest:query-param("anteQuem", "{$anteQuem}")
    %rest:query-param("postQuem", "{$postQuem}")
    %rest:query-param("date", "{$date}")
    %rest:query-param("dateBabylonian", "{$dateBabylonian}")
    %rest:query-param("ductus", "{$ductus}")
function api:list-tablets-as-json($text as xs:string*, $region as xs:string*, $archive as xs:string*, $dossier as xs:string*, $scribe as xs:string*, $city as xs:string*, $period as xs:string*, $anteQuem as xs:string*, $postQuem as xs:string*, $date as xs:string*, $dateBabylonian as xs:string*, $ductus as xs:string*) {
    let $tablets-filtered := api:do-filter-tablets($text, $region, $archive, $dossier, $scribe, $city, $period, $anteQuem, $postQuem, $date, $dateBabylonian, $ductus)
    let $tablets-as-objects := 
        for $t in $tablets-filtered
        let $attributes := tablet:get-attributes($t/@xml:id)
        return cfdb:object(for $k in map:keys($attributes) return cfdb:property($k, map:get($attributes, $k))) 
    return
        if (xmldb:get-current-user() = $config:authorized-users)
        then cfdb:array($tablets-as-objects)
        else api:status("unauthorized", "You are not allowed to access this service")
};

(:~ list tablets as XML 
 : @param $text: filter tablets by text reference (exact match) 
 : @param $region: filter tablets by region (case insensitive substring match)
 : @param $archive: filter tablets by archive (case insensitive substring match)
 : @param $dossier: filter tablets by dossier (case insensitive substring match) 
 : @param $scribe: filter tablets by scribe (case insensitive substring match)
 : @param $city: filter tablets by city (case insensitive substring match)
 : @param $periodd: filter tablets by period (substring match)
 : @param $anteQuem: filter tablets by anteQuem date (exact match)
 : @param $postQuem: filter tablets by anteQuem date (exact match)
 : @param $date: filter tablets by date (exact match)
 : @param $dateBabylonian: filter tablets by babylonian date (exact match)
 : @param $ductus: filter tablets by ductus attribute(exact match)
 : NB: only GET is supported on this endpoint 
 :)
declare 
    %rest:GET
    %rest:path("/cfdb/tablets")
    %rest:produces("application/xml")
    %output:media-type("application/xml")
    %rest:query-param("text", "{$text}")
    %rest:query-param("region", "{$region}")
    %rest:query-param("archive", "{$archive}")
    %rest:query-param("dossier", "{$dossier}")
    %rest:query-param("scribe", "{$scribe}")
    %rest:query-param("city", "{$city}")
    %rest:query-param("period", "{$period}")
    %rest:query-param("anteQuem", "{$anteQuem}")
    %rest:query-param("postQuem", "{$postQuem}")
    %rest:query-param("date", "{$date}")
    %rest:query-param("dateBabylonian", "{$dateBabylonian}")
    %rest:query-param("ductus", "{$ductus}")
function api:list-tablets-as-xml($text as xs:string*, $region as xs:string*, $archive as xs:string*, $dossier as xs:string*, $scribe as xs:string*, $city as xs:string*, $period as xs:string*, $anteQuem as xs:string*, $postQuem as xs:string*, $date as xs:string*, $dateBabylonian as xs:string*, $ductus as xs:string*) {
    let $tablets-filtered := api:do-filter-tablets($text, $region, $archive, $dossier, $scribe, $city, $period, $anteQuem, $postQuem, $date, $dateBabylonian, $ductus)
    let $tablets-as-xml := 
        for $t in $tablets-filtered/@xml:id!tablet:get-attributes(.)
        return <tablet>{for $k in map:keys($t) return element {$k} {map:get($t, $k)}}</tablet>
    return
        if (xmldb:get-current-user() = $config:authorized-users)
        then <cfdb:response items="{count($tablets-filtered)}">{$tablets-as-xml}</cfdb:response>
        else api:status("unauthorized", "You are not allowed to access this service")
};


(:~
 : This helper function converts REST query parameters to XML elements and calls cfdb:tablets().
 :)
declare %private function api:do-filter-tablets($text as xs:string*, $region as xs:string*, $archive as xs:string*, $dossier as xs:string*, $scribe as xs:string*, $city as xs:string*, $period as xs:string*, $anteQuem as xs:string*, $postQuem as xs:string*, $date as xs:string*, $dateBabylonian as xs:string*, $ductus as xs:string*) {
    let $filter := (
        if ($text != '') then <filter key="text">{$text[1]}</filter> else (),
        if ($region != '') then <filter key="region">{$region[1]}</filter> else (),
        if ($archive != '') then <filter key="archive">{$archive[1]}</filter> else (),
        if ($dossier != '') then <filter key="dossier">{$dossier[1]}</filter> else (),
        if ($scribe != '') then <filter key="scribe">{$scribe[1]}</filter> else (),
        if ($city != '') then <filter key="city">{$city[1]}</filter> else (),
        if ($period != '') then <filter key="period">{$period[1]}</filter> else (),
        if ($anteQuem != '') then <filter key="anteQuem">{$anteQuem[1]}</filter> else (),
        if ($postQuem != '') then <filter key="postQuem">{$postQuem[1]}</filter> else (),
        if ($date != '') then <filter key="date">{$date[1]}</filter> else (),
        if ($dateBabylonian != '') then <filter key="dateBabylonian">{$dateBabylonian[1]}</filter> else (),
        if ($ductus != '') then <filter key="ductus">{$ductus[1]}</filter> else ()
    )
    return cfdb:tablets($filter)
};



(: get all attributes of a tablet :)
declare 
    %rest:GET
    %rest:path("/cfdb/tablet/{$tablet-id}")
    %rest:produces("application/json")
    %output:media-type("application/json")
function api:get-tablet-attributes($tablet-id) {
    let $attributes := tablet:get-attributes($tablet-id)
    let $response := <cfdb:response>{
        for $key in map:keys($attributes)[. != ''] 
        return element {$key} {map:get($attributes, $key)}
    }</cfdb:response>
    let $user := xmldb:get-current-user()
    return 
        if ($user = $config:authorized-users)
        then util:serialize($response,"method=json")
        else api:status("unauthorized", "You are not allowed to access this service")
};

declare 
    %rest:GET
    %rest:path("/cfdb/tablet/{$tablet-id}/{$attribute}")
    %rest:produces("application/json")
    %output:media-type("application/json")
function api:get-tablet-attribute($tablet-id, $attribute) {
    let $attributes := tablet:get-attributes($tablet-id, $attribute)
    let $response := <cfdb:response>{
        for $key in map:keys($attributes)[. != ''] 
        return element {$key} {map:get($attributes, $key)}
    }</cfdb:response>
    let $user := xmldb:get-current-user()
    return 
        if ($user = $config:authorized-users)
        then util:serialize($response,"method=json")
        else api:status("unauthorized", "You are not allowed to access this service")
};

declare 
    %rest:PUT("{$data}")
    %rest:path("/cfdb/tablet/{$tablet-id}/{$attribute}")
    %rest:consumes("text/plain")
    %rest:produces("application/json")
    %output:media-type("application/json")
function api:get-tablet-attribute($tablet-id, $attribute, $data) {
    let $attributes := tablet:set-attribute($tablet-id, $attribute, util:base64-decode($data))
    let $response := <cfdb:response>{
        for $key in map:keys($attributes)[. != ''] 
        return element {$key} {map:get($attributes, $key)}
    }</cfdb:response>
    let $user := xmldb:get-current-user()
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
    let $annotation :=  annotation:read($tablet, $surface-id, $annotation-id, $filter)
    let $response := 
        if (exists($tablet))
        then <cfdb:response>{$data}</cfdb:response> 
        else "tablet with id "||$tablet-id||" not available"
    return util:serialize($response,"method=json")
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