xquery version "3.0";

declare default element namespace "http://www.tei-c.org/ns/1.0";

update insert <tei:note></tei:note> into collection('/db/cfdb-data/tablets')//tei:origDate