xquery version "3.0";

declare namespace tei="http://www.tei-c.org/ns/1.0";
(:the command below produces a not tei-conform result as obviosly the order of elements in tei:char has to be charName, charProp, figure but the command below inserts charProp AFTER figure:)
(:update insert <tei:charProp><tei:localName>KL number</tei:localName><tei:value></tei:value></tei:charProp> into collection('/db/cfdb-data/etc/stdSigns')//tei:char[not(./tei:charProp)]:)
 
(: using "following" does the trick :)
 update insert <tei:charProp><tei:localName>KL number</tei:localName><tei:value></tei:value></tei:charProp> following collection('/db/cfdb-data/etc/stdSigns')//tei:char[not(./tei:charProp)]/tei:charName

(:command to delete all tei:charProp elements:)
(:for $x in collection('/db/cfdb-data/etc/stdSigns')//tei:charProp:)
(:return:)
(:    update delete $x:)