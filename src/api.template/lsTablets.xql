xquery version "3.0";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config="@app.uri@/config" at "xmldb:exist://db/apps/@app.name@/modules/config.xqm";
import module namespace cfdb = "@app.uri@/db" at "xmldb:exist:///db/apps/@app.name@/modules/cfdb.xqm";

let $user := xmldb:get-current-user()
let $log := util:log-app("DEBUG", $config:app-name, "lsTablets.xql called by " ||$user)
let $tablets := 
    for $t in cfdb:tablets() 
    return 
        map{
            "id" 		:= $t/xs:string(@xml:id),
            "idno" 	:= $t/tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:msDesc/tei:msIdentifier/data(tei:idno),
            "filename"	:= util:document-name($t),
           	"path"		:= util:collection-name($t)
        }
return 
<tablets xmlns="">{
	for $t in $tablets
	let $permissions := sm:get-permissions($t("path"))
	let $editable := if ($permissions/*/@owner = $user or $user = sm:get-group-members("cfdbEditors")) then true() else false()
	order by $t("idno") 
	return
	<tablet editable="{if ($editable) then 1 else 0}">
		<id>{$t("id")}</id>
		<path>{$t("path")}</path>
		<idno>{$t("idno")}</idno>
	</tablet>
}</tablets>
