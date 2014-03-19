dashing-sensu
=============

A widget for Shopify's dashing project to display Sensu warning and critical alerts.

The sample dashboard provided shows a summary widget, either showing 'OK' or containing the number of warning and/or critical alerts (coloured green, yellow or red, respectively).

Configuration
=============

Copy the widget directory and jobfile into your dashing installation, optionally using the sample dashboard.

You may need to edit the sensu job file to change SENSU_API_ENDPOINT if your sensu installation is not running at localhost.

Screenshot
==========

![image](https://raw.github.com/mrichar1/dashing-sensu/master/assets/dashing-sensu-example.png)


Acknowledgements
================

This widget is based on the [dashing-nagios widget](https://github.com/aelse/dashing-nagios), while the sensu job code is based on the example provided here: https://gist.github.com/codingfoo/5535577
