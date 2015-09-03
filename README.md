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

Add a user to one of the cfdb groups:
 
- cfdbEditors can access and change all tablets
- cfdbAnnotators can access and change only their own tablets
- cfdbReaders have read-only access

Access the application at http://localhost:8080/exist/apps/{app-name as set in build.properties}. 

! Important: the webapp makes use of betterform's upload functionality, so make sure that the upload directory specified in $EXIST_HOME/extensions/betterform/main/webapp/WEB-INF/betterform-config.xml property name="uploadDir" (default: $EXIST_HOME/webapp/upload) exists and is writeable to the exist-process.


   