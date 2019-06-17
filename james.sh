#!/bin/bash

ls "james/manifests/"*.json | while read manifests; do

  echo "==> Process manifest '${manifests}'"

  jps=$(jq -r '.url' "${manifests}")
  jps="${jps%/}"
  jps_purged=$(jq -r '.url' "${manifests}" | sed 's~http[s]*://~~g')

  managed=$(jq -r '.managed' "${manifests}")

  if [ "${managed}" == "true" ]; then

    if [ "$(curl -sL -w "%{http_code}" "${jps}/healthCheck.html" -o /dev/null)" == "200" ]; then
      if [ $(curl -s "${jps}/healthCheck.html") == "[]" ]; then

        echo "==> JPS '${jps}' is available and health check passed"

        ls -d "james/templates/"* | while read templates; do

          templates=$(basename ${templates})
          templates_purged=$(basename ${templates} | cut -c 4-)
          echo "==> Process resource '${templates_purged}'"

          for elements in $(jq --arg t "policies-remove" '.[$t] | length' "${manifests}"); do
            elements=$(expr $elements - 1)
            for n in $(seq 0 $elements); do
              object=$(jq -r --arg t "remove" --arg n "${n}" '.[$t][$n | tonumber]' "${manifests}")
              object_purged=$(echo "${object}" | sed -e 's/ /%20/g' 2>/dev/null)
              if [ "$(curl -sL -H "authorization: Basic ${credentials}" -w "%{http_code}" "${jps}/JSSResource/policies/name/${object_purged}" -o /dev/null)" == "200" ]; then
                echo "[$n] Remove policy '${object}' on '${jps_purged}'"
                curl -s -o "/dev/null" --show-error -H "authorization: Basic ${credentials}" "${jps}/JSSResource/policies/name/${object_purged}" -X DELETE
              fi
            done
          done

          for elements in $(jq --arg t "${templates_purged}" '.[$t] | length' "${manifests}"); do
            elements=$(expr $elements - 1)
            for n in $(seq 0 $elements); do

              object=$(jq -r --arg t "${templates_purged}" --arg n "${n}" '.[$t][$n | tonumber]' "${manifests}")
              object_purged=$(echo "${object}" | sed -e 's/ /%20/g' 2>/dev/null)

              if [ "$(curl -sL -H "authorization: Basic ${credentials}" -w "%{http_code}" "${jps}/JSSResource/${templates_purged}/name/${object_purged}" -o /dev/null)" == "200" ]; then
                if [ -s "james/templates/${templates}/${object}.xml" ]; then

                  echo "[$n] Update resource '${templates_purged}/${object}' on '${jps_purged}'"
                  curl -s -o "/dev/null" --show-error -H "authorization: Basic ${credentials}" -H "content-type: application/xml" -T "james/templates/${templates}/${object}.xml" "${jps}/JSSResource/${templates_purged}/name/${object_purged}" -X PUT

                  if [ -s "james/icons/${object}.png" ]; then
                    icon="james/icons/${object}.png"
                    object_id=$(curl -s -H "authorization: Basic ${credentials}" -H "accept: application/xml" -X "GET" "${jps}/JSSResource/policies/name/${object_purged}" | xmllint --xpath "/policy/general/id/text()" -)
                    if [ -z "$(curl -s -H "authorization: Basic ${credentials}" "${jps}/JSSResource/policies/name/${object_purged}" | xmllint --xpath "/policy/self_service/self_service_icon/filename/text()" - 2> /dev/null)" ]; then
                      echo "Add Self Service icon '${icon}' to policy '${object_purged}'"
                      curl -s -o "/dev/null" --show-error -H "authorization: Basic ${credentials}" -X "POST" -F name=@"${icon}" "${jps}/JSSResource/fileuploads/policies/id/${object_id}"
                    fi
                  fi

                fi
              elif [ "$(curl -sL -H "authorization: Basic ${credentials}" -w "%{http_code}" "${jps}/JSSResource/${templates_purged}/name/${object_purged}" -o /dev/null)" == "404" ]; then
                if [ -s "james/templates/${templates}/${object}.xml" ]; then

                  echo "[$n] Add resource '${templates_purged}/${object}' on '${jps_purged}'"
                  curl -s -o "/dev/null" --show-error -H "authorization: Basic ${credentials}" -H "content-type: application/xml" -T "james/templates/${templates}/${object}.xml" "${jps}/JSSResource/${templates_purged}/id/0" -X POST

                  if [ -s "james/icons/${object}.png" ]; then
                    icon="james/icons/${object}.png"
                    object_id=$(curl -s -H "authorization: Basic ${credentials}" -H "accept: application/xml" -X "GET" "${jps}/JSSResource/policies/name/${object_purged}" | xmllint --xpath "/policy/general/id/text()" -)
                    if [ -z "$(curl -s -H "authorization: Basic ${credentials}" "${jps}/JSSResource/policies/name/${object_purged}" | xmllint --xpath "/policy/self_service/self_service_icon/filename/text()" - 2> /dev/null)" ]; then
                      echo "Add Self Service icon '${icon}' to policy '${object_purged}'"
                      curl -s -o "/dev/null" --show-error -H "authorization: Basic ${credentials}" -X "POST" -F name=@"${icon}" "${jps}/JSSResource/fileuploads/policies/id/${object_id}"
                    fi
                  fi

                fi
              fi

            done
          done

        done

      fi
    fi

  elif [ "${managed}" == "false" ]; then
    echo "==> Context '${jps}' is not managed"
  fi

done