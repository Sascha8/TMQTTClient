# MQTT-Client for Delphi based on the work of Jamie Ingilby and Daniele Teti

Based roughly on MQTT Spec v3.0 and most important part of 3.1 - **full UTF-8 support**. 
- Currently no support for login via user/password to broker.
- QoS 0 only 
- See "Limitations" below

## Works well in Delphi Berlin

Latest Fixes:
- Changes to correct UTF8 encoding in TBytes - using IndyTextEncoding_UTF8.GetString() instead of TEncoding.ANSI.GetString();
- Memory leak in HandleData() fixed through not raised exeption
- ThreadHandling optimized.
- Added Timer for KeepAlive-Ping to Client. Default 60 sec. Changing vtimeout via consructor possible.



## LIMITATIONS:
This is not a reference implementation of the MQTT Protocol but does support both Publishing Messages and Subscribing to Topics with the following limitations: 
	- It only allows and supports QoS 0 Messages. I haven’t built QoS levels 1 or 2 in yet as I 	personally have no need for them but this is planned for future versions.
	- ~~You are required to schedule pinging the server yourself (using a TTimer for examples). 	The client library implements a ping command but doesn’t automatically ping the server 	itself at regular intervals.~~



## USAGE:
There is a sample project included in the download but usage is relatively simple. 


