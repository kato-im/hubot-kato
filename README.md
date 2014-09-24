# Kato Hubot Adapter

## Description

The Kato Hubot adapter allows you to send messages to Hubot from a Kato room and receive messages back.

## Installation

Install hubot (consult with [hubot documentation](https://github.com/github/hubot/tree/master/docs) for more information)

    $ sudo npm install -g hubot coffee-script

Create new bot

    $ hubot --create myhubot
    $ cd myhubot

Add `hubot-kato` as dependency in `package.json`, so that dependencies section will look like:
```
  "dependencies": {
    "hubot-kato":    ">= 0.0.7",
    "hubot":         ">= 2.6.0 < 3.0.0",
    "hubot-scripts": ">= 2.5.0 < 3.0.0"
  },
```

Install depenencies with

    $ npm install

Start Hubot with

    $ ./bin/hubot -a kato

## Usage

You will need to set some environment variables to use this adapter:

    $ export HUBOT_KATO_ROOMS="d2506b04fb529cb77cbe03daad7e8"

    $ export HUBOT_KATO_LOGIN="kato-bot@mycompany.com"

    $ export HUBOT_KATO_PASSWORD="mycompanybot"

## Copyright

Copyright &copy; LeChat, Inc. See LICENSE for details.
