# OpenNMS Requisitions
Scripts that generate XML requisitions for use with OpenNMS to automate monitored nodes and services 

## Examples

### azurereq.sh

Run from command line:
    azurereq.sh > /tmp/azurereq.xml
    
OR

Set up a cron job like:
    0 0 * * * /usr/local/sbin/azurereq.sh > /tmp/azurereq.xml

AND

Add the following to provisiond-configuration.xml

    <requisition-def import-name="AzureAPI" import-url-resource="file:///tmp/azurereq.xml">
      <cron-schedule>0 10 5,17 * * ? *</cron-schedule>
    </requisition-def>

and then reload the provisiond-configuration file:

    send-event.pl uei.opennms.org/internal/reloadDaemonConfig --parm 'daemonName Collectd'

OR

Run from the command line with send-event.pl

    send-event.pl uei.opennms.org/internal/importer/reloadImport --parm 'url file:///tmp/azurereq.xml'
