xquery version "3.0";

declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace tei="http://www.tei-c.org/ns/1.0";

for $document in collection('db/cfdb-data/tablets/')//tei:TEI
return
    <item>hansi</item>