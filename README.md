Bot Spot
=======
Four plugins for openkore:
1. botspot.pl - Our bread and butter! This plugin registers a command `dunk [player name]`, which initiates the dunk process on any matched player
2. ignore.pl - A plugin which hooks into botspot to detect and ignore spammers
3. exec.pl - This plugin allows for arbitrary command execution via PMs and party messages from predefined characters
4. walk.pl - Records and replays routes


Howdo?
=======
Put this folder inside your openkore directory.


Notes
=======
1. You'll probably want to put this in your lead character's config.txt
```
botspot_admin 1
```


2. You can enable a dunk log by adding the following line in your config.txt
```
logToFile_Debug dunk_log=dunks.txt
```


3. To walk automatically:
..* `record start`
..* move around for a while
..* `record stop`
..* `record save`
..* `replay start`
