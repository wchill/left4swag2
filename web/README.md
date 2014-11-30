###Web

#####Dependencies  
* Python 2.x  
* Flask  
* virtualenv
* uWSGI  
* nginx

#####Install
* Change paths in `uwsgi.ini` and `nginx.conf` if necessary. (By default it assumes `/home/l4d2server/web`)  
* Copy `uwsgi.ini` to `/etc/uwsgi/vassals` and `nginx.conf` to `/etc/nginx/sites-enabled` (if you have something already running on port 80, you will need to modify your configuration)  
* Create an entry for uWSGI in `/etc/init` so it can run on system startup in emperor mode

#####Details
Currently just a simple text-based MOTD with corresponding banner. Using Flask, it keeps track of the last server reboot (really the last time Flask was restarted) and how many players (non-unique) have connected since then and displays it as part of the MOTD.

Plan on adding statistics and stuff later.
