# Kato Hubot Adapter

## Description

The Kato Hubot adapter allows you to send messages to Hubot from a Kato room and receive messages back.

## Installation

Install Hubot (consult the [Hubot documentation](https://github.com/github/hubot/tree/master/docs) for more information):

    $ sudo npm install -g hubot coffee-script

Create a new bot (or update your existing one):

    $ hubot --create myhubot
    $ cd myhubot

Add `hubot-kato` as a dependency in `package.json`, so that the dependencies section looks something like this:

```json
"dependencies": {
  "hubot-kato":    ">= 0.0.9",
  "hubot":         ">= 2.6.0 < 3.0.0",
  "hubot-scripts": ">= 2.5.0 < 3.0.0"
}
```

If you already have a bot that uses a different adapter, simply remove that from `package.json` and add the Kato adapter instead.

Then install the dependencies:

    $ npm install

## Configuration

First, create a new Kato account for your bot. It’s best to create a new email, eg. `kato-bot@mycompany.com`.
Then invite it to your organization, creating a new account. Confirm the email and set a name for your bot in its new account (that name shows up when it posts a message).

Next, you will need to set some environment variables:

    $ export HUBOT_KATO_LOGIN="kato-bot@mycompany.com"
    $ export HUBOT_KATO_PASSWORD="mycompanybot"

## Usage

Once that’s done, you can start Hubot with Kato as the adapter:

    $ ./bin/hubot -a kato

### Notes
Kato addapter supports listening for commands in a rooms and 1 on 1 chats.
You can address your bot by beginning a message with its name, which defaults to "Hubot".
(Bot not listening messages from user which credentials is used for Hubot login)

You can change this and also set an alias using the following additional environment vars:

    $ export HUBOT_NAME="Frank"
    $ export HUBOT_ALIAS="!"

Your bot should now answer `!ping` with `PONG`.

#### Logging option
Optional log filename (by default filename is kato-hubot.log):

    $ export HUBOT_KATO_LOG_FILE="filename.log" 
    
or 

    $ export HUBOT_KATO_LOG_FILE="path/filename.log"
     
Optional log level (common values 'error', 'debug', 'info', 'silly'):

    $ export HUBOT_KATO_LOG_LEVEL="debug" 


## Copyright

Copyright &copy; LeChat, Inc. See LICENSE for details.
