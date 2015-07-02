class gitlab_mirrors::mirror_list(
  $mirror_list_repo,
  $mirror_list_repo_path,
  $ensure_mirror_sync_job    = present,
  $system_mirror_user        = 'gitmirror',
  $system_mirror_group       = 'gitmirror',
  $gitlab_mirrors_repo_dir_path,
  $mirrors_list_yaml_file    = 'mirror_list.yaml',
  $ensure_mirror_list_repo_cron_job = present,
  $system_user_home_dir
) {

  $mirror_list = "${mirror_list_repo_path}/${mirrors_list_yaml_file}"

  File{
    owner => $system_mirror_user,
    group => $system_mirror_group
  }

# it is expected that you will be maintaining a separate repo that contains the mirror_list yaml file
# since we want this repo to always have the latest list we create a cron job for it
  git{$mirror_list_repo_path:
    ensure  => present,
    branch  => 'master',
    latest  => true,
    origin  => $mirror_list_repo,
    before  => Cron['sync mirror list repo'],
    notify  => Exec["chown ${mirror_list_repo_path}"],
    require => Package['git']
  }
  exec{"chown ${mirror_list_repo_path}":
    command => "chown -R ${system_mirror_user}:${system_mirror_group} ${mirror_list_repo_path}",
    path => ['/bin', '/usr/bin'],
    refreshonly => true,
  }
  cron{'sync mirror list repo':
    ensure => $ensure_mirror_list_repo_cron_job,
    command => "cd ${mirror_list_repo_path} && git pull 2>&1 > /dev/null",
    minute => '05',
  }

  file{"${system_user_home_dir}/sync_mirrors.rb":
    ensure => file,
    source => "puppet:///modules/gitlab_mirrors/sync_mirrors.rb",
    require => Git[$mirror_list_repo_path],
    mode => 750
  }
  cron{'gitlab mirrors sync job':
    command => "${system_user_home_dir}/sync_mirrors.rb $gitlab_mirrors_repo_dir_path $mirror_list 2>&1 > /dev/null",
    ensure => $ensure_mirror_sync_job,
    hour => '*',
    minute => '10',
    user => $system_mirror_user,
    require => File["${system_user_home_dir}/sync_mirrors.rb"]
  }

}
