#!/bin/bash
#
# This script will generate an XML requisition file for use with OpenNMS
# from Microsoft Azure to automate adding and removing of virtual
# machines (nodes), and which services should be added to those nodes.
#
# Copyright 2021 Chris Manigan
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Replace values for Application (client ID), Application Secret and
# Directory (tenant) ID with your own that has Read permissions to
# Azure Virtual Machines

APPLICATIONID="Application (client) ID"
APPLICATIONSECRET="Application Secret"
TENANTID="Directory (tenant) ID"

if ! command -v az >/dev/null 2>&1 ; then
    echo "az command not found, please install az"
    exit 0
fi

if ! command -v xmllint >/dev/null 2>&1 ; then
    echo "xmllint command not found, please install xmllint"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1 ; then
    echo "jq not found, please install jq"
    exit 0
fi

az login --service-principal -u "${APPLICATIONID}" -p "${APPLICATIONSECRET}" --tenant "${TENANTID}" --output none

DATE="$(date --utc +%FT%TZ)"
XML="<model-import xmlns=\"http://xmlns.opennms.org/xsd/config/model-import\" date-stamp=\"${DATE}\" foreign-source=\"Azure\" last-import=\"${DATE}\">"

for RESOURCEGROUP in $(az group list --query [].name --output tsv)
do

    for NODE in $(az vm list --resource-group "${RESOURCEGROUP}" --query "[].{NodeLabel:name, Tags:tags, OS:storageProfile.osDisk.osType, VM:vmId}" --output json | jq -c '.[]'); do

        _jq()
        {
            echo ${NODE} | jq -r ${1}
        }

        NODELABEL=$(_jq '.NodeLabel')
        OS=$(_jq '.OS')
        ENVIRONMENT=$(_jq '.Tags.Environment')
	VMID=$(_jq '.VM')
        if [ "$ENVIRONMENT" = "Production" ]; then
            LOCATION=$(_jq '.NodeLabel')
            PUBIP=$(az vm list-ip-addresses --resource-group "${RESOURCEGROUP}" --name "${NODELABEL}" --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)

            # TODO: GeoIP lookup of IP address to populate city, state, zip, country, latitue, longitude

            XML=$XML"

   <node building=\"${RESOURCEGROUP}\" foreign-id=\"${VMID}\" node-label=\"${NODELABEL}\">
      <interface ip-addr=\"$PUBIP\" status=\"1\" snmp-primary=\"P\">
         <!-- <monitored-service service-name=\"HTTP\"/> -->
      </interface>
      <category name=\"Azure\"/>
      <category name=\"${LOCATION}\"/>
      <category name=\"${RESOURCEGROUP}\"/>
      <category name=\"${ENVIRONMENT}\"/>
      <category name=\"${OS}\"/>
      <asset name=\"city\" value=\"\"/>
      <asset name=\"state\" value=\"\"/>
      <asset name=\"zip\" value=\"\"/>
      <asset name=\"country\" value=\"\"/>
      <asset name=\"latitude\" value=\"\"/>
      <asset name=\"longitude\" value=\"\"/>
   </node>
"
        fi
    done
done

XML=$XML"</model-import>"

echo "$XML" | xmllint --format -
