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
URL.

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

### Slash-commands

Before being sent to the server, slash-commands are parsed by the client, and simple
regular expression substitutions can be performed. These substitutions are called
"macros". The default macros are shown below.

<table style="font-family: monospace">
	<tr style="font-family: Lucida Grande, Helvetica, Verdana, sans-serif">
		<th>Macro</th>
		<th>Result</th>
	</tr>
	<tr>
		<td>/me [text]</td>
		<td>PRIVMSG $CURR_VIEW :\0x01ACTION [text]\0x01</td>
	</tr>
	<tr>
		<td>/ctcp [target] [message]</td>
		<td>PRIVMSG [target] :\0x01[message]\0x01</td>
	</tr>
	<tr>
		<td>/msg [who] [what]</td>
		<td>PRIVMSG $1 :$2</td>
	</tr>
	<tr>
		<td>/part [where] [message]</td>
		<td>PART [where] :[message]</td>
	</tr>
	<tr>
		<td>/kick [who] [message]</td>
		<td>KICK $CURR_VIEW [who] :[message]</td>
	</tr>
	<tr>
		<td>/quit [message]</td>
		<td>QUIT :[message]</td>
	</tr>
	<tr>
		<td>/topic [new_topic]</td>
		<td>TOPIC $CURR_VIEW :[new_topic]</td>
	</tr>
</table>

### Adding your own

You can add/change/remove macros to your heart's content by going to Settings->Advanced->Macros.
The regexes are standard Perl-compatible regular expressions. In the result, the variables
`$1` through `$9` are replaced by the respective matches, and `$CURR_VIEW` is replaced by the
current view selected.
