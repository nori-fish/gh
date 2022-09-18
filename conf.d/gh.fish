function _gh_install --on-event gh_install --on-event gh_update
    set --query gh_package_content_type || set --local gh_package_content_type application/gzip
    set --query gh_package_name_contains || set --local gh_package_name_contains linux_amd64
    set --local current_version

    if command --query gh
        set current_version (command gh version | head -n1 | awk '{print $3}')
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

        curl --progress-bar -Lo "$file_path" "$download_url"
        set --query GH_INSTALL
        or set --universal --export GH_INSTALL $HOME/.gh

        rm -rf $GH_INSTALL
        mkdir -p $GH_INSTALL
        tar -C $GH_INSTALL --strip-components=1 -xzf "$file_path"
        rm -rf $tmp_dir

        fish_add_path --prepend $GH_INSTALL/bin

        if not gh auth status -t &| grep Token: >/dev/null
            command gh auth login
        end
    end
end

function _gh_uninstall --on-event gh_uninstall
    if set --local index (contains --index $GH_INSTALL/bin $fish_user_paths)
        set --universal --erase fish_user_paths[$index]
    end

    if set --query GH_INSTALL
        rm -rf $GH_INSTALL
        set -Ue GH_INSTALL
    end
end
