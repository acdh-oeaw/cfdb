xquery version "3.0";

(:declare namespace api = "http://acdh.oeaw.ac.at/cfdb2/api";:)
declare namespace tei = "http://www.tei-c.org/ns/1.0";
import module namespace api = "@app.uri@/api" at "xmldb:exist://db/apps/@app.name@/modules/api.xqm";
import module namespace config="@app.uri@/config" at "xmldb:exist://db/apps/@app.name@/modules/config.xqm";

import module namespace cfdb = "@app.uri@/db" at "xmldb:exist:///db/apps/@app.name@/modules/cfdb.xqm";

let $user := xmldb:get-current-user()
let $log := util:log-app("DEBUG", $config:app-name, "lsTablets.xql called by " ||$user)
let $tablets := 
    for $t in cfdb:tablets() 
    return 
        map{
            "id" 		:= $t/xs:string(@xml:id),
            "title" 	:= $t/tei:teiHeader/tei:fileDesc/tei:titleStmt/data(tei:title),
            "filename"	:= util:document-name($t),
           	"path"		:= util:collection-name($t)
        }
return 
<tablets xmlns="">{
	for $t in $tablets
	let $permissions := sm:get-permissions($t("path"))
	let $editable := if ($permissions/*/@owner = $user or $user = $config:superusers) then true() else false()
	order by $t("title") 
	return
	<tablet editable="{if ($editable) then 1 else 0}">
		<id>{$t("id")}</id>
		<path>{$t("path")}</path>
		<title>{$t("title")}</title>
	</tablet>
}</tablets>
