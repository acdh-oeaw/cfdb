cfdb - cuneiform DB
======================

This is a database for cuneiform tablets and signs, based on exist-db and betterFORM.

Setup

# Install

## Get the code

1. git clone https://{USERNAME}@acdh.oeaw.ac.at/redmine/cfdb.git
e.g: https://pandorfer@acdh.oeaw.ac.at/redmine/cfdb.git 

2. git checkout in-browser-editing

## Build it

1. open command prompt(cmd)

2. change directory to /cfdb

3. copy, paste and rename build.properties.default to build.properties

4. open *build.properties* and adapt to your needs

    1. add an app.name

5. back in the command prompt run:  *ant*

6. in your /cfdb directory check if there is a directory  /cfdb/build

7. open it and see if you find a *.xar* package. This package should carry the name you set in the *build.properties* 

## Install it

1. start your local exist-db instance

2. open your favorite browser and browse to exist-db´s dashboard, usually found at: [http://localhost:8080/exist/apps/dashboard/index.html](http://localhost:8080/exist/apps/dashboard/index.html) 

3. click on the ‘Package Manager’ tile and here on the ‘add package’ sign (in the top left corner)

4. Upload your recently built package *{yourappsname}.xar*

5. close the package manager

6. on the dashboard you should find a new application named *{yourappsname}*

7. before happily clicking on it

8. click on the ‘User Manager’-tile and add your user (probably the ‘admin’) to ‘cfdbEditors’. **Important:** Make sure that the user has a non-empty password.     

# Try it

1. Now click on the on the tile in the dashboard which carries the name  *{yourappsname} *and you should see a log in screen where which accepts your (admin)credentials. 


 
- cfdbEditors can access and change all tablets
- cfdbAnnotators can access and change only their own tablets
- cfdbReaders have read-only access

Access the application at http://localhost:8080/exist/apps/{app-name as set in build.properties}. 

! Important: the webapp makes use of betterform's upload functionality, so make sure that the upload directory specified in 
`$EXIST_HOME/extensions/betterform/main/webapp/WEB-INF/betterform-config.xml property name="uploadDir" (default: $EXIST_HOME/webapp/upload)` exists and is writeable to the exist-process.


   