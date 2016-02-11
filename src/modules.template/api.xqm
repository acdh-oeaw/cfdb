xquery version "3.0";

module namespace api = "@app.uri@/api";

import module namespace config="@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";
import module namespace cfdb = "@app.uri@/db" at "xmldb:exist:///db/apps/@app.name@/modules/cfdb.xqm";
import module namespace tablet = "@app.uri@/tablet" at "xmldb:exist:///db/apps/@app.name@/modules/tablet.xqm";
import module namespace surface = "@app.uri@/surface" at "xmldb:exist:///db/apps/@app.name@/modules/surface.xqm";
import module namespace annotation = "@app.uri@/annotations" at "xmldb:exist:///db/apps/@app.name@/modules/annotations.xqm";
import module namespace archive = "@app.uri@/archive" at "xmldb:exist:///db/apps/@app.name@/modules/archive.xqm";
import module namespace xqjson = "http://xqilla.sourceforge.net/lib/xqjson";
import module namespace app="@app.uri@/templates" at "xmldb:exist:///db/apps/@app.name@/modules/app.xql";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function api:format-response-payload($items as item()*, $format as xs:string, $status, $caller as xs:string) as element(api:reponse) {
    <cfdb:response status="{$status}" query="{$caller}" timestamp="{current-dateTime()}" user="{xmldb:get-current-user()}" format="{$format}" items="{count($items)}">{
    for $i in $items
    return
        typeswitch ($i) 
            case element() return 
                if ($format eq "xml") then $i
                else if ($format eq "json") then <cfdb:payload>{$i}</cfdb:payload> 
                else data($i) 
            case map() return
                if ($format eq "xml") then <cfdb:item>{for $key in map:keys($i) return <cfdb:property name="{$key}">{map:get($i, $key)}</cfdb:property>}</cfdb:item> else
                if ($format eq "json") then <cfdb:payload>{for $key in map:keys($i) return element {$key} {map:get($i, $key)}}</cfdb:payload> 
                else string-join((for $key in $i return concat($key, ":", map:get($i, $key))), "
")
            default return 
                if ($format eq "xml") then <cfdb:payload>{$i}</cfdb:payload> else 
                if ($format eq "json") then <cfdb:payload>{$i}</cfdb:payload> 
                else $i
    }</cfdb:response>
};

(:~ This function creates an empty, non-200 response with an empty payload 
 : and $msg being used as the reason for the     
 :)
declare function api:response($status, $msg) {
    api:response($status, $msg, (), ())
};

(:~
 : Creates a REST response, including status, status message and payload in a given format ("xml", "json" or "text")
 : If status code is other than 200 the payload will be empty and the second paramter will be used as the status message to be passed as the http response code reason. 
 :)
declare function api:response($status, $load, $format as xs:string?, $caller as xs:string?) {
    let $statusCode := 
        switch(true())
            case $status = "error"          return 500
            case $status = "unauthorized"   return 401
            case $status = "missing parameter" case $status = "invalid request data" return 400
            (:case $status = "invalid request data" return 422:)
            (: 422 is not accepted by RestXQ, so we have to use 400 :)
            case $status = "insufficent permissions" return 403
            default return 200
    let $content-type := 
        switch($format) 
            case "json" return "application/json"
            case "html" return "application/xhtml+xml"
            case "text" return "text/plain"
            default return "application/xml" 
    let $ser :=
        <output:serialization-parameters>
            <output:method value="{$format}"/>
        </output:serialization-parameters>
    return (
        <rest:response>
            {$ser}
            <http:response status="{$statusCode}">
                {if ($statusCode != 200) then attribute reason {$load} else ()}
                <http:header name="Content-Type" value="{$content-type}"/>
            </http:response>            
        </rest:response>,
        if ($statusCode = 200) 
        then api:format-response-payload($load, $format, $status, $caller)
        else api:format-response-payload($load, "text", $status, $caller)
)};


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
            let $id := $t/xs:string(@xml:id)
            let $attributes := tablet:get-attributes($id)
            let $object := cfdb:object(for $k in map:keys($attributes) return cfdb:property($k, map:get($attributes, $k)))
            return $object
    return
        if (xmldb:get-current-user() = $config:authorized-users)
        then cfdb:array($tablets-as-objects)
        else api:response("unauthorized", "You are not allowed to access this service")
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
        else api:response("unauthorized", "You are not allowed to access this service")
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
        else api:response("unauthorized", "You are not allowed to access this service")
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
        else api:response("unauthorized", "You are not allowed to access this service")
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
        else api:response("unauthorized", "You are not allowed to access this service")
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
        else map {"status" := "error" , "msg" := concat("tablet with id ", $tablet-id, " not available")}
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


(: ********************************:)
(: ********** ANNOTATIONS *********:)
(: ********************************:)


(:~ lists all occurences in the whole database :)
declare 
    %rest:GET
    %rest:path("/cfdb/signs")
    %rest:header-param("format", "{$format}", "xml")
function api:list-all-annotations($format as xs:string*) {
    let $payload := cfdb:list-annotations()
    return api:response("ok", $payload, $format, "api:list-annotations()")
};

(:~ lists all occurences of a given sign type in the whole database :)
declare 
    %rest:GET
    %rest:path("/cfdb/signs/type/{$type}")
    %rest:header-param("format", "{$format}", "xml")
function api:list-annotations-by-sign-type($type as xs:string, $format as xs:string*) {
    let $payload :=  cfdb:list-annotations("sign-type", $type) 
    return api:response("ok", $payload, $format, "api:list-annotations()")
};


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
                else api:response("unauthorized", "You are not allowed to access this service")
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



(:~ list all standard signs :)
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



(: ******************************** :)
(: ****** ARCHIVE endpoints ******* :)
(: ******************************** :)

(:~ Fetches a list of snaphots in JSON 
 :)
declare 
    %rest:GET
    %rest:path("/cfdb/archive")
    %rest:produces("application/json")
    %output:media-type("application/json")
function api:list-archive() {
    util:serialize(<response>{for $a in archive:list() return archive:get-extra-metadata($a)}</response>, "method=json")
};

(:~ Fetches a full HTML representation of the list of snaphots as presented by archive.html
 :)
declare 
    %rest:GET
    %rest:path("/cfdb/archive")
    %rest:produces("application/xhtml+xml")
    %output:media-type("application/xhtml+xml")
function api:list-archive() {
    app:archivelist((),())
};

(:~ Uploads a new snaphot. 
 :)
declare 
    %rest:POST("{$data}")
    %rest:path("/cfdb/archive")
    %rest:query-param("name", "{$filename}")
    %rest:query-param("deploy", "{$deploy}")
    %rest:header-param("format", "{$format}", "json")
function api:upload-snapshot($data, $filename as xs:string*, $deploy as xs:boolean*, $format as xs:string*) {
    let $import := archive:import($filename, $data)
    (:let $deploy := if ($deploy[1] eq true()) then archive:deploy() else ():)
(:    return api:response("ok", "uploaded successfully"):)
    return api:response(if ($import instance of element(error)) then "error" else "ok", $import, $format, "api:upload-snapshot")
};

(:~ CREATES a new snaphot of the version $version 
 :)
declare 
    %rest:POST
    %rest:path("/cfdb/archive/{$version}")
    %rest:query-param("pid", "{$pid}")
    %rest:header-param("user", "{$user}")
    %rest:header-param("password", "{$password}")
    %rest:header-param("format", "{$format}", "json")
function api:create-snapshot($user as xs:string*, $password as xs:string*, $version as xs:string, $pid as xs:string*, $format as xs:string*) {
    let $login := true()(:xmldb:login($config:data-root, $user[1], $password[1]):),
        $caller := "api:create-snapshot"
    return 
        if ($login)
        then
            if (xmldb:get-current-user() = $config:editors)
            then
                let $md := archive:create($version, $pid[1])
                return 
                    if ($md instance of element(error))
                    then 
                        let $data :=  
                            if ($format = "html") 
                            then <p xmlns="http://www.w3.org/1999/xhtml">{xs:string($md)}</p> 
                            else $md
                        return api:response("error", $data, $format, $caller) 
                    else 
                        let $data := archive:get-extra-metadata($md)
                        return api:response("ok", $data , $format, $caller)
            else api:response("insufficient permissions", "user "||xmldb:get-current-user()||" has insufficent rights to create an archive", $format, $caller)
        else api:response("unauthorized", "Unknown user or invalid credentials", $format, $caller) 
};


(:~ DEPLOYS the snaphot with the id $id  
 :)
declare 
    %rest:PUT
    %rest:path("/cfdb/archive/{$id}")
    %rest:query-param("removeDeployedSnaphot", "{$removeDeployedSnaphot}")
    %rest:header-param("format", "{$format}", "json")
function api:deploy-snapshot($id as xs:string, $removeDeployedSnaphot as xs:string*, $format as xs:string*) {
    let $login := true()(:xmldb:login($config:data-root, $user[1], $password[1]):),
        $caller := "api:deploy-snapshot",
        $rmCurrent := ($removeDeployedSnaphot[1],false())[. castable as xs:boolean][1]
    return 
        if ($login)
        then
            if (xmldb:get-current-user() = $config:editors)
            then
                if ($rmCurrent castable as xs:boolean)
                then 
                    let $deploy := archive:deploy($id, $rmCurrent)
                    return 
                        if ($deploy instance of element(error))
                        then api:response("error", $deploy, $format, $caller) 
                        else api:response("ok", $deploy , $format, $caller)
                else api:response("error", "Query parameter 'removeDeployedSnapshot' ("||$removeDeployedSnaphot||") must be castable to xs:boolean.", $format, $caller)
            else api:response("insufficient permissions", "user "||xmldb:get-current-user()||" has insufficent rights to deploy an archive", $format, $caller)
        else api:response("unauthorized", "Unknown user or invalid credentials", $format, $caller) 
};

(:~ DELETES the snaphot with the id $id.:)
declare 
    %rest:DELETE
    %rest:path("/cfdb/archive/{$id}")
    %rest:header-param("user", "{$user}")
    %rest:header-param("password", "{$password}")
    %rest:header-param("format", "{$format}", "json")
function api:remove-snapshot($user as xs:string*, $password as xs:string*, $id as xs:string, $format as xs:string*) {
    let $login := true()(:xmldb:login($config:data-root, $user[1], $password[1]):),
        $caller := "api:remove-snapshot"
    return
        if ($login)
        then
            if (xmldb:get-current-user() = $config:editors)
            then
                let $md := archive:remove($id)
                return 
                    if ($md instance of element(error))
                    then api:response("error", $md, $format, $caller)
                    else api:response("ok", "Successfully removed snapshot "||$id, $format, $caller)
            else api:response("insufficient permissions", "Unknown user or invalid credentials", $format, $caller)
        else api:response("unauthorized", "Unknown user or invalid credentials", $format, $caller)
};


(:~ DELETES the artefacts of snaphot with the id $id.:)
declare 
    %rest:DELETE
    %rest:path("/cfdb/archive/artefacts/{$id}")
    %rest:header-param("format", "{$format}", "json")
function api:remove-snapshot-artefacts($id as xs:string, $format as xs:string*) {
    let $caller := "api:remove-snapshot-artefacts"
    return
        if (xmldb:get-current-user() = $config:editors)
        then
            let $md := archive:remove-artefacts($id)
            return 
                if ($md instance of element(error))
                then api:response("error", $md, $format, $caller)
                else api:response("ok", "Successfully removed snapshot artefacts "||$id, $format, $caller)
        else api:response("insufficient permissions", "Must be member of cfdb:editor group to remove artefacts", $format, $caller)
};

(: ******************************** :)
(: **** DATABASE CONFIGURATION **** :)
(: ******************************** :)

declare 
    %rest:GET
    %rest:path("/cfdb/configuration")
    %rest:header-param("format", "{$format}", "json")
function api:get-instance-settings($format as xs:string*) {
    api:get-instance-settings((), $format)
};

declare 
    %rest:GET
    %rest:path("/cfdb/configuration/{$key}")
    %rest:header-param("format", "{$format}", "json")
function api:get-instance-settings($key as xs:string*, $format as xs:string*) {
    let $value := config:get($key[1])
    return 
        if (not(xmldb:get-current-user() = $config:editors)) then api:response("insufficient permissions", "must be editor to view configuration", $format, "api:get-instance-settings")
        else if ($value instance of element(error)) then api:response("error", $value, $format, "api:get-instance-settings")
        else api:response("ok", $value, $format, "api:get-instance-settings")
};


declare 
    %rest:PUT("{$value}")
    %rest:path("/cfdb/configuration")
    %rest:header-param("format", "{$format}", "json")
    %output:media-type("application/json")
function api:set-instance-settings($key as xs:string*, $value as item()*, $format as xs:string*) {  
        if (not(xmldb:get-current-user() = $config:editors)) 
        then api:response("insufficient permissions", "must be editor to view configuration", $format, "api:get-instance-settings")
        else 
            let $data := util:base64-decode($value),
                $log := util:log-app("DEBUG", $config:app-name, $value),
                $xml := try { xqjson:parse-json($data) } catch * {<error>could not parse {$data} as a JSON object</error>},
                $keys := $xml//pair/@name[. = $config:keys]/xs:string(.),
                $map := map:new(for $k in $keys return map:entry($k, $xml//pair[@name = $k]/xs:string(.)))
            let $response := config:set($map)
            return 
                if ($response instance of element(error))
                then api:response("error", $response)
                else api:response("ok", $response, $format, "api:set-instance-settings")
};