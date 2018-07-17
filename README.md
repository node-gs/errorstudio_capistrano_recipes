# Error Studio Capistrano Recipes

At [Error](https://error.agency) we like to deploy things with Capistrano. This is a selection of our scripts for deploying:

* Rails
* Wordpress (using the [Bedrock](https://roots.io/bedrock/) approach and composer)
* Static sites

There are some optional parts too:

* Nginx config with SSL
* RVM setup
* Phusion Passenger configuration
* Cron jobs

# Warning / Disclaimer
This is mostly an internal tool - you'll have to spelunk through the code to get a handle on all the options.

# Prerequisites
On the machine you're deploying from, you'll need:

* Ruby
* GPG 2 (for decrypting secret SSL keys locally)

# License
MIT - see LICENSE.txt


