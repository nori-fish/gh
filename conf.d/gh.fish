function _gh_install --on-event gh_install --on-event gh_update
    set --query gh_package_content_type || set --local gh_package_content_type application/x-debian-package
    set --query gh_package_name_contains || set --local gh_package_name_contains linux_amd64
    set --local current_version
    set --local gh_path

    if which gh >/dev/null
        set gh_path (which gh)
        set current_version ($gh_path version | head -n1 | awk '{print $3}')
    end

    set --local latest_release_json (curl -fs https://api.github.com/repos/cli/cli/releases/latest)
    set --local latest_version (echo $latest_release_json | jq -r ".tag_name" | sed -e "s#^v##" | awk '{print $1}')

    if [ "$current_version" != "$latest_version" ]
        if [ "$current_version" ]
            echo "[gh] Updating from v$current_version to v$latest_version..."
        else
            echo "[gh] Installing v$latest_version"
        end

        set --local latest_release_asset (
			echo $latest_release_json \
				| jq ".assets[]	| select(.content_type==\"$gh_package_content_type\") | select(.name | contains(\"$gh_package_name_contains\"))" \
			)

        if [ -z "$latest_release_asset" ]
            echo "Unable to find a release asset of type '$gh_package_content_type' with name containing '$gh_package_name_contains'"
            exit 1
        end

        set --local name (echo $latest_release_asset | jq -r ".name")
        set --local label (echo $latest_release_asset | jq -r ".label")
        set --local download_url (echo $latest_release_asset | jq -r ".browser_download_url")
        set --local tmp_dir (mktemp -d /tmp/gh.XXXXXXX)
        set --local file_path $tmp_dir/$name

        if [ "$label" ]
            set name "$name ($label)"
        end

        curl -sLo "$file_path" "$download_url" >/dev/null
        sudo dpkg -i "$file_path" >/dev/null
        rm -rf $tmp_dir

        if not test "$current_version"
            command gh auth login
        end
    end
end

function _gh_uninstall --on-event gh_uninstall
    sudo dpkg -r gh
end
