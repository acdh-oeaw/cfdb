xquery version "3.0";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "modules/config.xqm";

import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";

let $login := login:set-user("cfdb.acdh.oeaw.ac.at", (), false())
let $authorized-user := xmldb:get-current-user() = $config:authorized-users
let $log := 
    if (xmldb:get-current-user()!='guest') 
    then 
        let $parameters := if (count(request:get-parameter-names()) gt 0) then "?"||string-join(for $x in request:get-parameter-names() return concat($x,"=",string-join(request:get-parameter($x,'')),','),'&amp;') else ()
        return util:log-app("DEBUG", $config:app-name, $exist:path||$parameters||" requested by " ||xmldb:get-current-user()||"@"||request:get-remote-addr())
    else ()
return

if ($exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>
else if (contains($exist:path,"$app-root")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/{substring-after($exist:path, '$app-root/')}">
            <set-header name="Cache-Control" value="no"/>
        </forward>
    </dispatch>
(:else if (starts-with($exist:path,"/edit") and ends-with($exist:resource, '.html')) then
    if (not($exist:resource = ('tablet.html', 'stdSigns.html', 'archives.html')))
    then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <redirect url="{replace(request:get-url(),'/edit/','/')}"/>
        </dispatch>
    else 
        if ($authorized-user)
        then 
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <forward url="{$exist:controller}/edit-{$exist:resource}"/>
                <view>
                    <forward url="{$exist:controller}/modules/view.xql"/>
                </view>
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
            </dispatch>:)
else if (ends-with($exist:resource, ".html")) then
    (: the html page is run through view.xql to expand templates :)
    if ($authorized-user)
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
else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="no"/>
    </dispatch>
