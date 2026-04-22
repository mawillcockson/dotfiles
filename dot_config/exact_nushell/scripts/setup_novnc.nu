use std/log

export const dependencies = [
  {command: oauth2-proxy, website: 'https://github.com/oauth2-proxy/oauth2-proxy/releases/latest'}
  {command: caddy, website: 'https://caddyserver.com/download'}
  {command: uv, website: 'https://docs.astral.sh/uv/getting-started/installation/'}
  {command: 7z, website: 'https://7-zip.org/download.html'}
]

export const novnc_source_url = 'https://github.com/novnc/noVNC/archive/refs/heads/master.zip'
export const oauth2_proxy_listen_address = '127.0.0.1:4180'
export const websockify_listen_address = '127.0.0.1:5189'
export const vnc_listen_address = '127.0.0.1:5900'

export def "get-name" []: nothing -> string {
  return (
    $env.CURRENT_FILE? |
    default './setup_novnc.nu' |
    path parse |
    get stem
  )
}

export def "env home" []: nothing -> path {
  let maybe_home = (echo '~/.' | path expand)
  return (
    [
      $env.HOME?
      (if ($maybe_home | path exists) {$maybe_home} else {null})
      $nu.home-path?
      $nu.home-dir?
    ] |
    compact --empty |
    first
  )
}
    
export def "env state" [name?: string]: nothing -> path {
  let name = ($name | default --empty (get-name))
  let state_dir = (
    $env.XDG_STATE_HOME? |
    default (echo $'(env home)/.local/state' | path expand) |
    path join $name
  )
  return $state_dir
}

export def "env data" [name?: string]: nothing -> path {
  let name = ($name | default --empty (get-name))
  let data_dir = (
    $env.XDG_DATA_HOME? |
    default (echo $'(env home)/.local/share' | path expand) |
    path join $name
  )
  return $data_dir
}

export def "env config" [name?: string]: nothing -> path {
  let name = ($name | default --empty (get-name))
  let config_dir = (
    $env.XDG_CONFIG_HOME? |
    default (echo $'(env home)/.config' | path expand) |
    path join $name
  )
  return $config_dir
}

export def main [] {
  check-dependencies
}

export def "list-dependencies" [] {
  return (
    echo $dependencies |
    insert path {|rec| which $rec.command | get path?.0?} |
    insert present {|rec| $rec.path | is-not-empty}
  )
}

export def "check-dependencies" [] {
  log info 'checking dependencies...'
  let dependencies = (list-dependencies)
  if ($dependencies | any {|dep| not $dep.present}) {
    log error 'missing dependencies'
    return (error make {
      msg: $"missing dependencies; view more with `list-dependencies`\n($dependencies | sort-by --reverse present | table)"
    })
  }
  log info 'all dependencies present'
}

export def "download novnc" [--force] {
  let web_root = (env data "novnc")
  if ($web_root | path exists) {
    if not $force {
      log info 'noVNC already downloaded'
      return $web_root
    }
    log warning $'removing old noVNC at ($web_root | to nuon)'
    rm -vr $web_root
  }
  log info $'making directory for noVNC at ($web_root | to nuon)'
  mkdir -v $web_root
  let tmpfile = (mktemp --suffix .zip)
  let tmpdir = (mktemp -d)
  log info $'downloading novnc to ($tmpfile | to nuon)'
  http get $novnc_source_url |
  save -f $tmpfile
  log info $'unpacking archive to ($tmpdir | to nuon)'
  # -spe: eliminate duplication of root folder for extract command
  7z x $'-o($tmpdir)' -spe $tmpfile
  log info $'moving files from ($tmpdir | to nuon) to ($web_root | to nuon)'
  do {
    cd $tmpdir
    glob --depth 2 ./*/* |
    mv -v ...($in) $web_root
  }
  log info $'removing temporary locations: ($tmpfile | to nuon), ($tmpdir | to nuon)'
  rm $tmpfile
  rm -r $tmpdir
  return $web_root
}

export def "run websockify" [] {
  let web_root = (download novnc)
  uv tool run ...([
    --no-env-file
    --no-config
    --python '3.12'
    --
    websockify@latest
    $'--web=($web_root)'
    $websockify_listen_address
    $vnc_listen_address
  ])
}

export def "run oauth2-proxy" [] {
  oauth2-proxy ...([
    $'--http-address=($oauth2_proxy_listen_address)'

    --provider=google
    $'--client-id=(input "OAuth2 Client ID: ")'
    $'--client-secret=(input "OAuth2 Client Secret: ")'

    --session-store-type=cookie
    --cookie-domain=vnc.willcockson.family
    $'--cookie-secret=(input "Cookie Secret: ")'
    --cookie-secure

    --authenticated-emails-file
  ])
}

export def "run caddy" [] {
  let config_path = (env config 'mw-caddy' | path join 'Caddyfile')
  generate config caddy | save -f $config_path
  caddy validate --config $config_path --adapter=caddyfile
  with-env {
    OAUTH2_PROXY_LISTEN_ADDRESS: $oauth2_proxy_listen_address,
    WEBSOCKIFY_LISTEN_ADDRESS: $websockify_listen_address,
  } {
    caddy run ...([
      $'--config=($config_path)'
      --adapter=caddyfile
    ])
  }
}

export def "generate config caddy" [] {
  return (
r##'
vnc.willcockson.family {
	# Requests to /oauth2/* are proxied to oauth2-proxy without authentication.
	# You can't use `reverse_proxy /oauth2/* oauth2-proxy.internal:4180` here because the reverse_proxy directive has lower precedence than the handle directive.
	handle /oauth2/* {
		reverse_proxy {env.OAUTH2_PROXY_LISTEN_ADDRESS} {
			# oauth2-proxy requires the X-Real-IP and X-Forwarded-{Proto,Host,Uri} headers.
			# The reverse_proxy directive automatically sets X-Forwarded-{For,Proto,Host} headers.
			header_up X-Real-IP {remote_host}
			header_up X-Forwarded-Uri {uri}
		}
	}

	# Requests to other paths are first processed by oauth2-proxy for authentication.
	handle {
		forward_auth {env.OAUTH2_PROXY_LISTEN_ADDRESS} {
			uri /oauth2/auth

			# oauth2-proxy requires the X-Real-IP and X-Forwarded-{Proto,Host,Uri} headers.
			# The forward_auth directive automatically sets the X-Forwarded-{For,Proto,Host,Method,Uri} headers.
			header_up X-Real-IP {remote_host}

			# If needed, you can copy headers from the oauth2-proxy response to the request sent to the upstream.
			# Make sure to configure the --set-xauthrequest flag to enable this feature.
			#copy_headers X-Auth-Request-User X-Auth-Request-Email

			# If oauth2-proxy returns a 401 status, redirect the client to the sign-in page.
			@error status 401
			handle_response @error {
				redir * /oauth2/sign_in?rd={scheme}://{host}{uri}
			}
		}

		# If oauth2-proxy returns a 2xx status, the request is then proxied to the upstream.
		reverse_proxy {env.WEBSOCKIFY_LISTEN_ADDRESS}
	}
}
'##
  )
}
