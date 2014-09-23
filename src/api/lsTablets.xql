xquery version "3.0";

declare namespace api = "http://acdh.oeaw.ac.at/cuneidb/api";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";

import module namespace tablet="http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";
  
<tablets xmlns="">{
	for $t in tablet:list() return
	<tablet>
		<id>{$t("id")}</id>
		<path>{$t("path")}</path>
		<title>{$t("title")}</title>
	</tablet>
}</tablets>
