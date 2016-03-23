xquery version "3.0";

declare namespace tei="http://www.tei-c.org/ns/1.0";

 update insert <tei:p/> following collection('/db/cfdb-data/tablets')//tei:handNote/tei:persName[@role="scribe"]
