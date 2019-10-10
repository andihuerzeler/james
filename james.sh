#!/bin/bash

find "james/manifests/"*.json | while read -r manifests; do

  echo "==> Process manifest '${manifests}'"

  jps=$(jq -r '.url' "${manifests}")
  jps="${jps%/}"
  jps_purged=$(jq -r '.url' "${manifests}" | sed 's~http[s]*://~~g')

  managed=$(jq -r '.managed' "${manifests}")

  if [ "${managed}" == "true" ]; then

    if [ "$(curl -sL -w "%{http_code}" "${jps}/healthCheck.html" -o /dev/null)" == "200" ]; then
      if [ "$(curl -s "${jps}/healthCheck.html")" == "[]" ]; then

        echo "==> JPS '${jps}' is available and health check passed"

        endpoint_list=(
          "categories"
          "computerextensionattributes"
          "computergroups"
          "packages"
          "policies"
          "osxconfigurationprofiles"
          "mobiledeviceextensionattributes"
          "mobiledevicegroups"
          "mobiledeviceapplications"
        )

        for endpoint in "${endpoint_list[@]}"; do

          for elements in $(jq --arg t "policies_remove" '.[$t] | length' "${manifests}"); do
            elements=$((elements - 1))
            for n in $(seq 0 "$elements"); do
              object=$(jq -r --arg t "policies_remove" --arg n "${n}" '.[$t][$n | tonumber]' "${manifests}")
              object_purged="${object// /%20}"
              if [ "$(curl -sL -H "Authorization: Basic ${credentials}" -w "%{http_code}" "${jps}/JSSResource/policies/name/${object_purged}" -o /dev/null)" == "200" ]; then
                echo "==> Remove policy '${object}' on '${jps_purged}'"
                curl -s -w "\n" -S -H "Authorization: Basic ${credentials}" "${jps}/JSSResource/policies/name/${object_purged}" -X DELETE
              fi
            done
          done

          echo "==> Process resource '${endpoint}'"

          for elements in $(jq --arg t "${endpoint}" '.[$t] | length' "${manifests}"); do
            elements=$((elements - 1))
            for n in $(seq 0 "$elements"); do
              object=$(jq -r --arg t "${endpoint}" --arg n "${n}" '.[$t][$n | tonumber]' "${manifests}")
              object_purged="${object// /%20}"
              if [ "$(curl -sL -H "Authorization: Basic ${credentials}" -w "%{http_code}" "${jps}/JSSResource/${endpoint}/name/${object_purged}" -o /dev/null)" == "200" ]; then
                if [ -s "james/templates/${endpoint}/${object}.xml" ]; then

                  echo "[$n] Update resource '${endpoint}/${object}' on '${jps_purged}'"
                  curl -s -w "\n" -S -H "Authorization: Basic ${credentials}" -H "Content-Type: application/xml" -T "james/templates/${endpoint}/${object}.xml" "${jps}/JSSResource/${endpoint}/name/${object_purged}" -X PUT

                  if [ -s "james/icons/${object/ Self Service/}.png" ]; then
                    icon="james/icons/${object/ Self Service/}.png"
                    object_id=$(curl -s -H "Authorization: Basic ${credentials}" -H "Accept: application/xml" -X "GET" "${jps}/JSSResource/policies/name/${object_purged}" | xmllint --xpath "/policy/general/id/text()" -)
                    if [ -z "$(curl -s -H "Authorization: Basic ${credentials}" "${jps}/JSSResource/policies/name/${object_purged}" | xmllint --xpath "/policy/self_service/self_service_icon/filename/text()" - 2>/dev/null)" ]; then
                      echo "Add Self Service icon '${icon}' to policy '${object_purged}'"
                      curl -s -w "\n" -S -H "Authorization: Basic ${credentials}" -X "POST" -F name=@"${icon}" "${jps}/JSSResource/fileuploads/policies/id/${object_id}"
                    fi
                  fi

                fi
              elif [ "$(curl -sL -H "Authorization: Basic ${credentials}" -w "%{http_code}" "${jps}/JSSResource/${endpoint}/name/${object_purged}" -o /dev/null)" == "404" ]; then
                if [ -s "james/templates/${endpoint}/${object}.xml" ]; then

                  echo "[$n] Add resource '${endpoint}/${object}' on '${jps_purged}'"
                  curl -s -w "\n" -S -H "Authorization: Basic ${credentials}" -H "Content-Type: application/xml" -T "james/templates/${endpoint}/${object}.xml" "${jps}/JSSResource/${endpoint}/id/0" -X POST

                  if [ -s "james/icons/${object/ Self Service/}.png" ]; then
                    icon="james/icons/${object/ Self Service/}.png"
                    object_id=$(curl -s -H "Authorization: Basic ${credentials}" -H "Accept: application/xml" -X "GET" "${jps}/JSSResource/policies/name/${object_purged}" | xmllint --xpath "/policy/general/id/text()" -)
                    if [ -z "$(curl -s -H "Authorization: Basic ${credentials}" "${jps}/JSSResource/policies/name/${object_purged}" | xmllint --xpath "/policy/self_service/self_service_icon/filename/text()" - 2>/dev/null)" ]; then
                      echo "Add Self Service icon '${icon}' to policy '${object_purged}'"
                      curl -s -w "\n" -S -H "Authorization: Basic ${credentials}" -X "POST" -F name=@"${icon}" "${jps}/JSSResource/fileuploads/policies/id/${object_id}"
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
