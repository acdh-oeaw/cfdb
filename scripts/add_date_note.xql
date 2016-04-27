xquery version "3.0";

declare namespace tei="http://www.tei-c.org/ns/1.0";

update insert <tei:note></tei:note> into collection('/db/cfdb-data/tablets')//tei:origDate

(:command to remove a second tei:note element:)
(:for $note in collection('/db/cfdb-data/tablets')//tei:origDate/tei:note[2]:)
(:return:)
(:    update delete $note:)