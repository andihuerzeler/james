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

        echo "==> JPS '${jps}' is available"

        ls -d "james/templates/"* | while read templates; do

          templates=$(basename ${templates})
          templates_purged=$(basename ${templates} | cut -c 4-)
          echo "==> Update '${templates_purged}'"

          for elements in $(jq --arg t "${templates_purged}" ' .[$t] | length' "${manifests}"); do
            elements=$(expr $elements - 1)
            for n in $(seq 0 $elements); do

              object=$(jq -r --arg t "${templates_purged}" --arg n "${n}" '.[$t][$n | tonumber]' "${manifests}")
              object_purged=$(echo "${object}" | sed -e 's/ /%20/g' 2>/dev/null)

              if [ "$(curl -sL -H "authorization: Basic ${credentials}" -w "%{http_code}" "${jps}/JSSResource/${templates_purged}/name/${object_purged}" -o /dev/null)" == "200" ]; then
                if [ -s "james/templates/${templates}/${object}.xml" ]; then

                  echo "[$n] Make PUT request on resource '${object}' to '${jps_purged}'"
                  curl -w "\n" -H "authorization: Basic ${credentials}" -H "content-type: application/xml" -T "james/templates/${templates}/${object}.xml" -s "${jps}/JSSResource/${templates_purged}/name/${object_purged}" -X PUT

                  ls james/icons/*.png | while read icons; do
                    if [ "${object}" = "$(basename '${icons}')" ]; then
                      icons=$(basename "${icons}")
                      icons_purged=$(echo "${icons}" | sed -e 's/ /%20/g' 2>/dev/null)
                      policy_name="${icons_purged%.*}"

                      if [ "$(curl -sL -H "authorization: Basic ${credentials}" -w "%{http_code}" "${jps}/JSSResource/policies/name/${policy_name}" -o /dev/null)" == "200" ]; then
                        policy_id=$(curl -s -H "authorization: Basic ${credentials}" -H "accept: application/xml" -X "GET" "${jps}/JSSResource/policies/name/${policy_name}" | xmllint --xpath "/policy/general/id/text()" -)
                        if [ -z "$(curl -s -H "authorization: Basic ${credentials}" "${jps}/JSSResource/policies/name/${policy_name}" | xmllint --xpath "/policy/self_service/self_service_icon/filename/text()" - 2> /dev/null)" ]; then
                          echo "==> Add Self Service icon '${icons}' to policy '${policy_name}'"
                          curl -w "\n" -s -H "authorization: Basic ${credentials}" -X "POST" -F name=@"james/icons/${icons}" "${jps}/JSSResource/fileuploads/policies/id/${policy_id}"
                        fi
                      fi
                    fi
                  done

                fi
              elif [ "$(curl -sL -H "authorization: Basic ${credentials}" -w "%{http_code}" "${jps}/JSSResource/${templates_purged}/name/${object_purged}" -o /dev/null)" == "404" ]; then
                if [ -s "james/templates/${templates}/${object}.xml" ]; then

                  echo "[$n] Make POST request on resource '${object}' to '${jps_purged}'"
                  curl -w "\n" -H "authorization: Basic ${credentials}" -H "content-type: application/xml" -T "james/templates/${templates}/${object}.xml" -s "${jps}/JSSResource/${templates_purged}/id/0" -X POST

                  ls james/icons/*.png | while read icons; do
                    if [ "${object}" = "$(basename '${icons}')" ]; then
                      icons=$(basename "${icons}")
                      icons_purged=$(echo "${icons}" | sed -e 's/ /%20/g' 2>/dev/null)
                      policy_name="${icons_purged%.*}"

                      if [ "$(curl -sL -H "authorization: Basic ${credentials}" -w "%{http_code}" "${jps}/JSSResource/policies/name/${policy_name}" -o /dev/null)" == "200" ]; then
                        policy_id=$(curl -s -H "authorization: Basic ${credentials}" -H "accept: application/xml" -X "GET" "${jps}/JSSResource/policies/name/${policy_name}" | xmllint --xpath "/policy/general/id/text()" -)
                        if [ -z "$(curl -s -H "authorization: Basic ${credentials}" "${jps}/JSSResource/policies/name/${policy_name}" | xmllint --xpath "/policy/self_service/self_service_icon/filename/text()" - 2> /dev/null)" ]; then
                          echo "==> Add Self Service icon '${icons}' to policy '${policy_name}'"
                          curl -w "\n" -s -H "authorization: Basic ${credentials}" -X "POST" -F name=@"james/icons/${icons}" "${jps}/JSSResource/fileuploads/policies/id/${policy_id}"
                        fi
                      fi
                    fi
                  done

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