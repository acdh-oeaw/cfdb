xquery version "3.0";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

import module namespace config="@app.uri@/config" at "modules/config.xqm";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";

declare variable $domain := $config:domain;


let $login := login:set-user($domain, (), false()),
    $user := request:get-attribute($domain||".user")

let $set-credentions :=
    if (request:get-parameter("password", ()) != '' and request:get-parameter("password", ()))
    then (
        session:set-attribute("user", $user),
        session:set-attribute("password", request:get-parameter("password", ()))
    )
    else ()
    
let $userAllowed := $user = $config:authorized-users

let $log := 
    if (xmldb:get-current-user()!='guest') 
    then 
        let $parameters := if (count(request:get-parameter-names()) gt 0) then "?"||string-join(for $x in request:get-parameter-names() return concat($x,"=",string-join(request:get-parameter($x,'')),','),'&amp;') else ()
        return util:log-app("DEBUG", $config:app-name, $exist:path||$parameters||" requested by " ||$user||"@"||request:get-remote-addr())
    else ()
return

if ($exist:path eq "/") then
    (: forward root path to index.html :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>

else if (contains($exist:path,"$tablets-root")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/../../{$config:tablets-root}/{substring-after($exist:path,'$tablets-root')}">
            <set-header name="Cache-Control" value="no"/>
        </forward>
    </dispatch>

else if (contains($exist:path,"$app-root/data")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/../../{$config:data-root}/{substring-after($exist:path,'$app-root/data')}">
            <set-header name="Cache-Control" value="no"/>
        </forward>
    </dispatch>

else if (contains($exist:path,"$app-root")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/{substring-after($exist:path, '$app-root/')}">
            <set-header name="Cache-Control" value="no"/>
        </forward>
    </dispatch>

(: when the instance is running in "public mode", access to the edit XForms and the annotate.xql is disabled :)
else if ($config:isPublicInstance and $exist:resource = ("editTablets.html", "editArchives.html", "editStdSigns.html", "annotate.xql")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/error-public-mode.html"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xql"/>
        </view>
    	<error-handler>
    		<forward url="{$exist:controller}/error-page.html" method="get"/>
    		<forward url="{$exist:controller}/modules/view.xql"/>
    	</error-handler>
    </dispatch>
    
else if (ends-with($exist:resource, ".html") or $exist:resource = "annotate.xql") then
    (: the html page is run through view.xql to expand templates :)
    if ($userAllowed or ($config:isPublicInstance and $exist:resource != "administration.html" ))
    then 
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <view>
                <forward url="{$exist:controller}/modules/view.xql"/>
            </view>
    		<error-handler>
    			<forward url="{$exist:controller}/error-page.html" method="get"/>
    			<forward url="{$exist:controller}/modules/view.xql"/>
    		</error-handler>
        </dispatch>
    else 
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}/login.html"/>
            <view>
                <forward url="{$exist:controller}/modules/view.xql"/>
            </view>
    		<error-handler>
    			<forward url="{$exist:controller}/error-page.html" method="get"/>
    			<forward url="{$exist:controller}/modules/view.xql"/>
    		</error-handler>
        </dispatch>

(: Resource paths starting with $shared are loaded from the shared-resources app :)
else if (contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>
    
(: paths for snapshots (ending with .zip) are mapped to the data/archive collection, 
   everything else is served by archive.html.
   This must be placed _after_ the /$shared/ part, because otherwise css imports are not 
   resolved correctly.
 :)
else if ($exist:path = "/archive") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="./archive.html"/>
    </dispatch>
    
else if (starts-with($exist:path,"/archive")) then
    if (ends-with($exist:resource, ".zip") or ends-with($exist:resource, ".xml"))
    then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="/../../{$config:data-root}/archive{substring-after($exist:path,'/archive')}">
                <set-header name="Cache-Control" value="no"/>
            </forward>
        </dispatch>
    else 
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}/archive.html"/>
            <view>
                <forward url="{$exist:controller}/modules/view.xql"/>
            </view>
    		<error-handler>
    			<forward url="{$exist:controller}/error-page.html" method="get"/>
    			<forward url="{$exist:controller}/modules/view.xql"/>
    		</error-handler>
        </dispatch>

else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="no"/>
    </dispatch>
