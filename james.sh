#!/bin/bash

ls "manifests/"*.json | while read manifests; do

  jps=$(jq -r '.url' "${manifests}")
  jps_purged=$(jq -r '.url' "${manifests}" | sed 's~http[s]*://~~g')
  echo "==> Process manifest '${manifests}'"

  if [ "$(curl -sL -w "%{http_code}" "${jps}/healthCheck.html" -o /dev/null)" == "200" ]; then

    echo "==> JPS '${jps}' is available"

    ls -d "templates/"* | while read templates; do

      templates=$(basename ${templates})
      templates_purged=$(basename ${templates} | cut -c 4-)
      echo "==> Update '${templates_purged}'"

      for elements in $(jq --arg t "${templates_purged}" ' .[$t] | length' "${manifests}"); do
        elements=$(expr $elements - 1)
        for n in $(seq 0 $elements); do

          object=$(jq -r --arg t "${templates_purged}" --arg n "${n}" '.[$t][$n | tonumber]' "${manifests}")
          object_purged=$(echo "${object}" | sed -e 's/ /%20/g' 2>/dev/null)

          if [ "$(curl -sL -H "authorization: Basic ${credentials}" -w "%{http_code}" "${jps}/JSSResource/${templates_purged}/name/${object_purged}" -o /dev/null)" == "200" ]; then
            if [ -s "templates/${templates}/${object}.xml" ]; then
              echo "[$n] Make PUT request on resource '${object}' to '${jps_purged}'"
              curl -w "\n" -H "authorization: Basic ${credentials}" -H "content-type: application/xml" -T "templates/${templates}/${object}.xml" -s "${jps}/JSSResource/${templates_purged}/name/${object_purged}" -X PUT
            fi
          elif [ "$(curl -sL -H "authorization: Basic ${credentials}" -w "%{http_code}" "${jps}/JSSResource/${templates_purged}/name/${object_purged}" -o /dev/null)" == "404" ]; then
            if [ -s "templates/${templates}/${object}.xml" ]; then
              echo "[$n] Make POST request on resource '${object}' to '${jps_purged}'"
              curl -w "\n" -H "authorization: Basic ${credentials}" -H "content-type: application/xml" -T "templates/${templates}/${object}.xml" -s "${jps}/JSSResource/${templates_purged}/id/0" -X POST
            fi
          fi

        done
      done

    done

  fi

done
