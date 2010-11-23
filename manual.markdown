---
layout: site
---

Manual
------

Once you've opened the client for the first time, the preferences window opens.
Most of the options should be self-explanatory. Some that require special attention:

* *Web browser:* This should be a full path. For example: `/usr/bin/firefox`
* *Timestamp format:* Parsed by `strftime`: See
[this page](http://linux.die.net/man/3/strftime) for details on recognized options.
* *Log date format:* Also parsed by `strftime`.

### Setting up networks

Create a network by clicking the "Add" button in the "Networks" tab of the preferences
window. Double-clicking on its name lets you edit it.

You can add/remove servers by clicking their respective buttons. You can then
edit the provided server URL; all parts are required. If the server has a password,
add it after the URL. Commands work in the same way.

### Connecting manually to a server

Go to Client->Connect... or press Ctrl-Shift-O. In the dialog, type the server's
URL, including the port.

### Using the client

The commands accepted are the standard IRC ones found in most clients. Going to
View->Open view... or pressing Ctrl-O lets you create a separate view for PMs.

Pressing tab while typing in the entry box attempts to complete your text with
the users in the current channel or the current view's name. Pressing tab again
after completion cycles through the list. Pressing the up and down arrow keys
cycles through the command history.

Pressing F2 opens the last link said in the chat. Ctrl-F2 opens the second-to-last
link.

### Config files and logs

Files are stored in `~/.config/xsirc`. The logs are stored in the `irclogs` folder.
