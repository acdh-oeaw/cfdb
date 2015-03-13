xquery version "3.0";

(:declare namespace api = "http://acdh.oeaw.ac.at/cuneidb/api";:)
declare namespace tei = "http://www.tei-c.org/ns/1.0";
import module namespace api = "http://www.oeaw.ac.at/acdh/cuneidb/api" at "xmldb:exist:///db/apps/cuneidb/modules/api.xqm";
import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";

import module namespace tablet="http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";

let $user := xmldb:get-current-user()
let $log := util:log-app("DEBUG", $config:app-name, "lsTablets.xql called by " ||$user)
let $tablets := tablet:list()
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
