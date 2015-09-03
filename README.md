cfdb - cuneiform DB
======================

This is a database for cuneiform tablets and signs, based on exist-db and betterFORM.

Setup

clone

cd to directory

cp build.properties.default > build.properties

adapt to own needs

> ant

move xar to server

! Important: the webapp makes use of betterform's upload functionality, so make sure that the upload directory specified in $EXIST_HOME/extensions/betterform/main/webapp/WEB-INF/betterform-config.xml property name="uploadDir" (default: $EXIST_HOME/webapp/upload) exists and is writeable to the exist-process.   